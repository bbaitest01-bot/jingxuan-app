-- ============================================================================
-- 4-E3a：通知中心第一版－拜訪紀錄整理完成／失敗通知（問題 M3、M4、M2）
-- 日期：2026-10-17
--
-- 設計見全景地圖 4-E ⑦（2026-10-17 修訂）：
--   1. 新建 notifications 表（不執行舊 migration 20260812 的通知段落，那裡的新增權限是 WITH CHECK (true)）
--   2. 通知只由資料庫觸發器產生：拜訪紀錄從「整理中」變成「完成／失敗」時，新增一則給紀錄的主人
--   3. 加入即時推送（Supabase Realtime），網頁開著時新通知馬上送到
--   4. 建立超過 30 天的通知併入每日清除
-- 權限：讀、刪除只能自己的；修改只能改 is_read（已讀）；沒有任何新增權限（App、n8n 都不能新增）。
-- 可重複執行：表、索引用 IF NOT EXISTS；政策、觸發器先 DROP IF EXISTS；publication 先檢查。
-- ============================================================================

-- 1. 通知資料表
CREATE TABLE IF NOT EXISTS public.notifications (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id              UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type                    TEXT        NOT NULL,
  title                   TEXT        NOT NULL,
  content                 TEXT        NOT NULL DEFAULT '',
  link_path               TEXT,
  target_visit_record_id  UUID        REFERENCES public.visit_records(id) ON DELETE CASCADE,
  is_read                 BOOLEAN     NOT NULL DEFAULT false,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- 第一版只有這三種；主管類通知將來要做時再用新 migration 加入
  CONSTRAINT notifications_type_check CHECK (type IN ('visit_record_ready', 'visit_record_failed', 'schedule_reminder')),
  CONSTRAINT notifications_title_length CHECK (char_length(title) BETWEEN 1 AND 100),
  CONSTRAINT notifications_content_length CHECK (char_length(content) <= 500),
  -- 只能是站內網址（例如 /visit-records/編號），避免被拿來導到外部網站
  CONSTRAINT notifications_link_path_check CHECK (link_path IS NULL OR link_path ~ '^/[A-Za-z0-9/_-]*$')
);

COMMENT ON TABLE public.notifications IS '通知中心（4-E3a）：只由資料庫觸發器或排程產生，本人只能讀、標已讀、刪除';
COMMENT ON COLUMN public.notifications.link_path IS '點通知要前往的站內網址';

-- 鈴鐺清單（自己的、新到舊）；拜訪紀錄永久刪除時一起刪通知用
CREATE INDEX IF NOT EXISTS idx_notifications_list
  ON public.notifications (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_visit_record
  ON public.notifications (target_visit_record_id);

-- 2. 權限（RLS）
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Own notifications select" ON public.notifications;
CREATE POLICY "Own notifications select"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Own notifications update" ON public.notifications;
CREATE POLICY "Own notifications update"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Own notifications delete" ON public.notifications;
CREATE POLICY "Own notifications delete"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

-- 沒有 INSERT 政策：登入者與未登入者都不能新增。再把欄位權限收緊：只能改「已讀」
REVOKE INSERT, UPDATE ON public.notifications FROM anon, authenticated;
REVOKE ALL ON public.notifications FROM anon;
GRANT SELECT, DELETE ON public.notifications TO authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;

-- 3. 觸發器：拜訪紀錄「整理中」→「完成／失敗」時新增一則通知給紀錄的主人
--    SECURITY DEFINER：以資料表擁有者身分新增（使用者本身沒有新增權限）
--    通知內容只放標題與失敗原因，不放拜訪內容本身（可能有客戶病史）
CREATE OR REPLACE FUNCTION public.notify_visit_record_organized()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status <> 'processing' OR NEW.status NOT IN ('done', 'failed') OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'done' THEN
    INSERT INTO public.notifications (profile_id, type, title, content, link_path, target_visit_record_id)
    VALUES (
      NEW.profile_id,
      'visit_record_ready',
      '拜訪紀錄已整理好',
      left('「' || NEW.title || '」已由 AI 整理完成，點這裡查看', 500),
      '/visit-records/' || NEW.id::text,
      NEW.id
    );
  ELSE
    INSERT INTO public.notifications (profile_id, type, title, content, link_path, target_visit_record_id)
    VALUES (
      NEW.profile_id,
      'visit_record_failed',
      '拜訪紀錄整理失敗',
      left('「' || NEW.title || '」：' || coalesce(NEW.failure_reason, '原因不明') || '。原始轉錄還在，可以重新整理', 500),
      '/visit-records/' || NEW.id::text,
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_visit_record_organized() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trigger_notify_visit_record_organized ON public.visit_records;
CREATE TRIGGER trigger_notify_visit_record_organized
  AFTER UPDATE OF status ON public.visit_records
  FOR EACH ROW EXECUTE FUNCTION public.notify_visit_record_organized();

-- 4. 即時推送：把 notifications 加進 Supabase Realtime（推送時一樣受上面的 RLS 限制）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

-- 5. 每日 00:00（UTC，台灣 08:00）自動清除：沿用 4-D 內容，加上 30 天前的通知
SELECT cron.schedule(
  'purge-deleted-data-daily',
  '0 0 * * *',
  $$
  DELETE FROM public.customers WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.reminders WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.schedule_events WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.visit_records WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.notifications WHERE created_at < NOW() - INTERVAL '30 days';
  $$
);
