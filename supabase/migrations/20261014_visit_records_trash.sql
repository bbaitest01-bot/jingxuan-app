-- ============================================================================
-- 4-D：拜訪紀錄刪除進垃圾桶（問題 R4、B2、B3）
-- 日期：2026-10-14
--
-- 做法：
--   1. visit_records 的 deleted_at 在 4-A 已建立，這裡只補垃圾桶查詢用的索引
--   2. 每日自動清除排程加入拜訪紀錄（放進垃圾桶超過 30 天就永久刪除）
-- 權限：沿用 4-A 的 RLS（只能讀寫、刪除自己的拜訪紀錄），不新增政策。
-- 可重複執行：索引用 IF NOT EXISTS；cron.schedule 同名工作會直接更新內容。
-- ============================================================================

-- 1. 垃圾桶列表與自動清除用（只索引已刪除的列）
CREATE INDEX IF NOT EXISTS idx_visit_records_deleted_at
  ON public.visit_records (profile_id, deleted_at)
  WHERE deleted_at IS NOT NULL;

-- 2. 每日 00:00（UTC，台灣 08:00）自動清除：保留客戶、提醒、行程，加上拜訪紀錄
SELECT cron.schedule(
  'purge-deleted-data-daily',
  '0 0 * * *',
  $$
  DELETE FROM public.customers WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.reminders WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.schedule_events WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.visit_records WHERE deleted_at < NOW() - INTERVAL '30 days';
  $$
);
