-- ============================================================================
-- 3-F：行程改成可還原的刪除（問題 S6、B1、B3）
-- 日期：2026-10-13
--
-- 原因：行程刪除是永久刪除（資料表沒有 deleted_at），垃圾桶看不到行程。
-- 做法：
--   1. schedule_events 加 deleted_at（有值＝在垃圾桶裡）
--   2. 每日自動清除排程加入「行程放進垃圾桶超過 30 天就永久刪除」
-- 權限：沿用既有 RLS「Agents can manage own schedule events」（只能管自己的，主管／開發者例外），
--       新欄位一樣受保護，不需新增政策。
-- 可重複執行：欄位、索引用 IF NOT EXISTS；cron.schedule 同名工作會直接更新內容。
-- ============================================================================

-- 1. 垃圾桶欄位
ALTER TABLE public.schedule_events
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

COMMENT ON COLUMN public.schedule_events.deleted_at IS '放進垃圾桶的時間；NULL＝正常行程。超過 30 天由每日排程永久刪除';

-- 垃圾桶列表與自動清除用（只索引已刪除的列，正常行程不佔空間）
CREATE INDEX IF NOT EXISTS idx_schedule_events_deleted_at
  ON public.schedule_events (profile_id, deleted_at)
  WHERE deleted_at IS NOT NULL;

-- 2. 每日 00:00（UTC）自動清除：保留原本的客戶、提醒，加上行程
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'purge-deleted-data-daily',
  '0 0 * * *',
  $$
  DELETE FROM public.customers WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.reminders WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM public.schedule_events WHERE deleted_at < NOW() - INTERVAL '30 days';
  $$
);
