-- ============================================================================
-- D36 比較清單：把選好的保單比較命名存到客戶下面（全景地圖 4-R，2026-11-10 沛沛確認）
--
-- customer_saved_comparisons：一次比較一筆，掛在客戶底下，不分客戶階段
--   scenario：情境與情境區填的數字（對應 ClaimScenarioInput）
--   items：比較的商品（照欄位順序，2～8 筆），含選的計畫、張數、保額、保費
--   只存填的數字，打開時用當下的條款資料重新計算金額
-- 權限：只有業務員本人能存取自己名下客戶的比較（只做業務員功能，不開放 is_admin_or_dev）
-- 客戶進垃圾桶時比較保留；永久刪除客戶時一起刪（ON DELETE CASCADE）
-- 可重複執行
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.customer_saved_comparisons (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id  UUID        NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  name         TEXT        NOT NULL,
  scenario     JSONB       NOT NULL DEFAULT '{}'::jsonb,
  items        JSONB       NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- 同一位客戶名稱不可重複；這個索引也負責「讀某位客戶的比較」，不用另外加
  CONSTRAINT saved_comparisons_customer_name_unique UNIQUE (customer_id, name),
  -- 名稱不可有頭尾空白，1～30 字
  CONSTRAINT saved_comparisons_name_check CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 30),
  CONSTRAINT saved_comparisons_scenario_check CHECK (jsonb_typeof(scenario) = 'object'),
  -- 比較至少 2 款，上限 8 款和比較頁相同
  CONSTRAINT saved_comparisons_items_check CHECK (jsonb_typeof(items) = 'array' AND jsonb_array_length(items) BETWEEN 2 AND 8)
);

COMMENT ON TABLE public.customer_saved_comparisons IS 'D36 比較清單：業務員為客戶存下的保單比較';
COMMENT ON COLUMN public.customer_saved_comparisons.scenario IS '情境試算填的數字（ClaimScenarioInput）';
COMMENT ON COLUMN public.customer_saved_comparisons.items IS '比較的商品陣列：product_id、plan_code、copies、coverage_amount、daily_amount、units、annual_premium';

ALTER TABLE public.customer_saved_comparisons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own customer saved comparisons" ON public.customer_saved_comparisons;
CREATE POLICY "Agents can manage own customer saved comparisons"
  ON public.customer_saved_comparisons FOR ALL
  TO authenticated
  USING (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
  )
  WITH CHECK (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
  );

REVOKE ALL ON public.customer_saved_comparisons FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customer_saved_comparisons TO authenticated;

-- 檢查：RLS 已開啟、有一條政策
SELECT
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.customer_saved_comparisons'::regclass) AS rls_enabled,
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'customer_saved_comparisons') AS policy_count;
