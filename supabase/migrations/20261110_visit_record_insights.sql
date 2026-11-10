-- ============================================================================
-- 拜訪紀錄重點與待辦草稿（全景地圖 4-Q）
-- 日期：2026-11-10
--
-- 用途：存 AI 從拜訪內容整理出的重點，以及待使用者確認的待辦草稿。
-- 權限：欄位在 visit_records 同一列，沿用既有 RLS（只有本人可讀寫，
--       主管、開發者看不到，2026-10-14 決定不變）。
-- 垃圾桶：刪除、還原、30 天清除都跟著同一列，不需另外處理。
-- 舊紀錄不回補，按「重新整理」才會產生。
-- 可重複執行：欄位用 IF NOT EXISTS；條件先 DROP IF EXISTS 再建立。
-- ============================================================================

ALTER TABLE public.visit_records
  ADD COLUMN IF NOT EXISTS key_points JSONB,
  ADD COLUMN IF NOT EXISTS follow_up_drafts JSONB;

COMMENT ON COLUMN public.visit_records.key_points IS 'AI 整理的重點：interviewee、needs、health_concerns、insurance_mentioned、next_steps';
COMMENT ON COLUMN public.visit_records.follow_up_drafts IS '待辦草稿（最多 5 筆）；draft_state：pending 待處理／accepted 已建立行程／dismissed 已略過';

ALTER TABLE public.visit_records DROP CONSTRAINT IF EXISTS visit_records_key_points_shape;
ALTER TABLE public.visit_records
  ADD CONSTRAINT visit_records_key_points_shape
  CHECK (key_points IS NULL OR jsonb_typeof(key_points) = 'object');

ALTER TABLE public.visit_records DROP CONSTRAINT IF EXISTS visit_records_follow_up_drafts_shape;
ALTER TABLE public.visit_records
  ADD CONSTRAINT visit_records_follow_up_drafts_shape
  CHECK (
    follow_up_drafts IS NULL
    OR CASE
      WHEN jsonb_typeof(follow_up_drafts) = 'array' THEN jsonb_array_length(follow_up_drafts) <= 5
      ELSE FALSE
    END
  );
