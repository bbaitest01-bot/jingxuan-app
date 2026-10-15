-- ============================================================================
-- 4-2a：專案拜訪改版資料表（問題 P2、P3、P6；設計見全景地圖 4-G）
-- 日期：2026-10-15
--
-- 一次建好 4-2 全部會用到的資料庫變更（4-2b～4-2d 不再改資料庫）：
--   1. visit_projects 加上週期、目標次數、固定期間起訖日、「日常拜訪」標記
--      舊專案自動改為「每月、目標＝名單人數（至少 1）」（2026-10-15 沛沛決定 A）
--   2. 新表 visit_results：每一次拜訪結果（○ positive／△ considering／× negative）
--   3. 觸發器：拜訪結果新增／修改／刪除後，客戶狀態＝該客戶「最新一筆」結果；
--      全部刪光就變回未設定（NULL）
--   4. schedule_events 加 visit_skipped_at：行程標記「沒拜訪」的時間（4-2c 使用）
-- 權限：visit_results 只能讀寫自己的；新增／修改時專案、客戶、拜訪紀錄、行程都必須是自己的。
--       主管／開發者先不開放看別人的（比照拜訪紀錄，主管功能暫緩）。
-- 可重複執行：欄位、表、索引用 IF NOT EXISTS；限制條件與政策先檢查或先刪再建。
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. visit_projects：週期＋目標次數
-- ---------------------------------------------------------------------------

-- 目的改為選填（新畫面叫「說明（選填）」）
ALTER TABLE public.visit_projects ALTER COLUMN purpose DROP NOT NULL;

ALTER TABLE public.visit_projects ADD COLUMN IF NOT EXISTS period_type TEXT NOT NULL DEFAULT 'month';
ALTER TABLE public.visit_projects ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE public.visit_projects ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE public.visit_projects ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;

-- 目標次數：第一次加欄位時，順便把舊專案的目標設成名單人數（重跑不會再改，避免蓋掉使用者改過的目標）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visit_projects' AND column_name = 'target_count'
  ) THEN
    ALTER TABLE public.visit_projects ADD COLUMN target_count INTEGER NOT NULL DEFAULT 10;
    UPDATE public.visit_projects p
    SET target_count = GREATEST(1, (
      SELECT COUNT(*) FROM public.visit_project_customers c WHERE c.visit_project_id = p.id
    ));
  END IF;
END $$;

COMMENT ON COLUMN public.visit_projects.period_type IS 'day／week／month／year＝重複（每期結束進度歸 0）；range＝固定期間（4-2a）';
COMMENT ON COLUMN public.visit_projects.start_date IS '固定期間開始日（只有 range 使用）';
COMMENT ON COLUMN public.visit_projects.end_date IS '固定期間結束日（只有 range 使用）';
COMMENT ON COLUMN public.visit_projects.target_count IS '每一期目標拜訪次數（1～1000）';
COMMENT ON COLUMN public.visit_projects.is_default IS '預設「日常拜訪」：每人一個、不能刪除';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'visit_projects_period_type_check'
                 AND conrelid = 'public.visit_projects'::regclass) THEN
    ALTER TABLE public.visit_projects ADD CONSTRAINT visit_projects_period_type_check CHECK (
      period_type IN ('day', 'week', 'month', 'year', 'range')
    );
  END IF;
  -- 固定期間一定要有起訖日，且結束日不可早於開始日
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'visit_projects_range_dates_check'
                 AND conrelid = 'public.visit_projects'::regclass) THEN
    ALTER TABLE public.visit_projects ADD CONSTRAINT visit_projects_range_dates_check CHECK (
      period_type <> 'range'
      OR (start_date IS NOT NULL AND end_date IS NOT NULL AND end_date >= start_date)
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'visit_projects_target_count_check'
                 AND conrelid = 'public.visit_projects'::regclass) THEN
    ALTER TABLE public.visit_projects ADD CONSTRAINT visit_projects_target_count_check CHECK (
      target_count BETWEEN 1 AND 1000
    );
  END IF;
END $$;

-- 每人只能有一個「日常拜訪」
CREATE UNIQUE INDEX IF NOT EXISTS idx_visit_projects_one_default
  ON public.visit_projects (profile_id)
  WHERE is_default;

-- 「日常拜訪」不能刪除、也不能取消預設標記（帳號被刪除時的連帶刪除不受影響）
CREATE OR REPLACE FUNCTION public.protect_default_visit_project()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    -- 帳號刪除時 profiles 那一列已經不在，允許連帶刪除
    IF OLD.is_default AND EXISTS (SELECT 1 FROM public.profiles WHERE id = OLD.profile_id) THEN
      RAISE EXCEPTION '日常拜訪是預設專案，不能刪除' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NEW.is_default IS DISTINCT FROM OLD.is_default THEN
    RAISE EXCEPTION '不能變更預設專案標記' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_protect_default_visit_project ON public.visit_projects;
CREATE TRIGGER trigger_protect_default_visit_project
  BEFORE UPDATE OR DELETE ON public.visit_projects
  FOR EACH ROW EXECUTE FUNCTION public.protect_default_visit_project();

-- ---------------------------------------------------------------------------
-- 2. visit_results：每一次拜訪結果
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.visit_results (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id         UUID        NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- 專案刪除時一起刪（P6，App 刪除前會提示）
  project_id         UUID        NOT NULL REFERENCES public.visit_projects(id) ON DELETE CASCADE,
  -- 客戶永久刪除時一起刪（放垃圾桶時保留）
  customer_id        UUID        NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  visited_on         DATE        NOT NULL,
  result             TEXT        NOT NULL,
  note               TEXT,
  -- 連結的拜訪紀錄被永久刪除時變空（P5）
  visit_record_id    UUID        REFERENCES public.visit_records(id) ON DELETE SET NULL,
  -- 來自哪個行程；行程被永久刪除時變空
  schedule_event_id  UUID        REFERENCES public.schedule_events(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- positive ○ 有意願／已成交、considering △ 考慮中／待跟進、negative × 無意願／暫不考慮（同客戶狀態）
  CONSTRAINT visit_results_result_check CHECK (result IN ('positive', 'considering', 'negative')),
  CONSTRAINT visit_results_note_length CHECK (note IS NULL OR char_length(note) <= 200)
);

COMMENT ON TABLE public.visit_results IS '專案拜訪結果（4-2）：每次拜訪一筆，只有本人可讀寫；最新一筆帶入客戶狀態';

-- 紀錄列表與圖表、客戶狀態計算、專案進度
CREATE INDEX IF NOT EXISTS idx_visit_results_profile_date
  ON public.visit_results (profile_id, visited_on DESC);
CREATE INDEX IF NOT EXISTS idx_visit_results_customer_latest
  ON public.visit_results (customer_id, visited_on DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_visit_results_project_date
  ON public.visit_results (project_id, visited_on);
CREATE INDEX IF NOT EXISTS idx_visit_results_visit_record
  ON public.visit_results (visit_record_id);
-- 一個行程只能有一筆結果
CREATE UNIQUE INDEX IF NOT EXISTS idx_visit_results_one_per_event
  ON public.visit_results (schedule_event_id)
  WHERE schedule_event_id IS NOT NULL;

DROP TRIGGER IF EXISTS trigger_update_visit_results_timestamp ON public.visit_results;
CREATE TRIGGER trigger_update_visit_results_timestamp
  BEFORE UPDATE ON public.visit_results
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS：只能讀寫自己的；關聯的專案、客戶、拜訪紀錄、行程都必須是自己的
ALTER TABLE public.visit_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Own visit results select" ON public.visit_results;
CREATE POLICY "Own visit results select"
  ON public.visit_results FOR SELECT
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Own visit results insert" ON public.visit_results;
CREATE POLICY "Own visit results insert"
  ON public.visit_results FOR INSERT
  TO authenticated
  WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND EXISTS (SELECT 1 FROM public.visit_projects p
                WHERE p.id = project_id AND p.profile_id = (SELECT auth.uid()))
    AND EXISTS (SELECT 1 FROM public.customers c
                WHERE c.id = customer_id AND c.profile_id = (SELECT auth.uid()))
    AND (visit_record_id IS NULL OR EXISTS (SELECT 1 FROM public.visit_records r
                WHERE r.id = visit_record_id AND r.profile_id = (SELECT auth.uid())))
    AND (schedule_event_id IS NULL OR EXISTS (SELECT 1 FROM public.schedule_events e
                WHERE e.id = schedule_event_id AND e.profile_id = (SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "Own visit results update" ON public.visit_results;
CREATE POLICY "Own visit results update"
  ON public.visit_results FOR UPDATE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND EXISTS (SELECT 1 FROM public.visit_projects p
                WHERE p.id = project_id AND p.profile_id = (SELECT auth.uid()))
    AND EXISTS (SELECT 1 FROM public.customers c
                WHERE c.id = customer_id AND c.profile_id = (SELECT auth.uid()))
    AND (visit_record_id IS NULL OR EXISTS (SELECT 1 FROM public.visit_records r
                WHERE r.id = visit_record_id AND r.profile_id = (SELECT auth.uid())))
    AND (schedule_event_id IS NULL OR EXISTS (SELECT 1 FROM public.schedule_events e
                WHERE e.id = schedule_event_id AND e.profile_id = (SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "Own visit results delete" ON public.visit_results;
CREATE POLICY "Own visit results delete"
  ON public.visit_results FOR DELETE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- 3. 客戶狀態＝最新一筆拜訪結果
-- ---------------------------------------------------------------------------

-- 重新計算一位客戶的狀態：最新一筆（拜訪日期新的優先，同一天看建立時間）；沒有任何結果＝NULL
CREATE OR REPLACE FUNCTION public.refresh_customer_client_status(target_customer_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  latest_result TEXT;
BEGIN
  SELECT r.result INTO latest_result
  FROM public.visit_results r
  WHERE r.customer_id = target_customer_id
  ORDER BY r.visited_on DESC, r.created_at DESC
  LIMIT 1;

  UPDATE public.customers
  SET client_status = latest_result
  WHERE id = target_customer_id
    AND client_status IS DISTINCT FROM latest_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_customer_client_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM public.refresh_customer_client_status(OLD.customer_id);
  END IF;
  -- 修改時換了客戶，新客戶也要重算
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.customer_id IS DISTINCT FROM OLD.customer_id) THEN
    PERFORM public.refresh_customer_client_status(NEW.customer_id);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_customer_client_status ON public.visit_results;
CREATE TRIGGER trigger_sync_customer_client_status
  AFTER INSERT OR UPDATE OR DELETE ON public.visit_results
  FOR EACH ROW EXECUTE FUNCTION public.sync_customer_client_status();

-- ---------------------------------------------------------------------------
-- 4. schedule_events：行程標記「沒拜訪」（4-2c 使用）
-- ---------------------------------------------------------------------------

ALTER TABLE public.schedule_events ADD COLUMN IF NOT EXISTS visit_skipped_at TIMESTAMPTZ;

COMMENT ON COLUMN public.schedule_events.visit_skipped_at IS '按「沒拜訪」的時間；空＝沒標記（4-2）';
