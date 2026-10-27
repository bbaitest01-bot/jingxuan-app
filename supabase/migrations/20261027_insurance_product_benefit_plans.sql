-- ============================================================================
-- 第 5 階段 D14：實支實付理賠限額（第二層比價資料）
-- 日期：2026-10-27
--
-- 設計見全景地圖 4-K（2026-10-27 沛沛確認）：
--   insurance_product_benefit_plans：每款商品的每個計畫一筆（例：富邦佳實在 計劃1／2／3 共三筆）
--   比較 7 項：每日病房、住院醫療費用（是否含手術）、住院手術、門診手術、總限額、自負額、住院日額
--   類型：itemized 分項限額／deductible 自負額／total 總額（不分項目）
--   金額一律新臺幣元；條款沒有的項目存空值
-- 資料來源：tool/benefit_plans/（程式讀官方條款給付表＋人工整理），由 supabase/seed/benefit_plans.sql 匯入
-- 權限：登入者只能讀（同 insurance_products）；app 不能新增、修改、刪除
-- 可重複執行
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.insurance_product_benefit_plans (
  id                                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id                         UUID        NOT NULL REFERENCES public.insurance_products(id) ON DELETE CASCADE,
  plan_code                          TEXT        NOT NULL,
  plan_order                         INTEGER     NOT NULL DEFAULT 1,
  benefit_type                       TEXT        NOT NULL DEFAULT 'itemized',
  room_daily_limit                   INTEGER,
  hospital_expense_limit             INTEGER,
  hospital_expense_includes_surgery  BOOLEAN     NOT NULL DEFAULT false,
  surgery_limit                      INTEGER,
  outpatient_surgery_limit           INTEGER,
  per_admission_total_limit          INTEGER,
  annual_total_limit                 INTEGER,
  lifetime_total_limit               INTEGER,
  room_deductible                    INTEGER,
  hospital_expense_deductible        INTEGER,
  outpatient_surgery_deductible      INTEGER,
  daily_hospital_benefit             INTEGER,
  note                               TEXT,
  source_page                        INTEGER,
  verified_at                        TIMESTAMPTZ,
  created_at                         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT benefit_plans_product_plan_unique UNIQUE (product_id, plan_code),
  CONSTRAINT benefit_plans_type_check CHECK (benefit_type IN ('itemized', 'deductible', 'total')),
  CONSTRAINT benefit_plans_plan_code_length CHECK (char_length(plan_code) BETWEEN 1 AND 40),
  -- 金額不能是負數
  CONSTRAINT benefit_plans_amounts_check CHECK (
    coalesce(room_daily_limit, 0) >= 0
    AND coalesce(hospital_expense_limit, 0) >= 0
    AND coalesce(surgery_limit, 0) >= 0
    AND coalesce(outpatient_surgery_limit, 0) >= 0
    AND coalesce(per_admission_total_limit, 0) >= 0
    AND coalesce(annual_total_limit, 0) >= 0
    AND coalesce(lifetime_total_limit, 0) >= 0
    AND coalesce(room_deductible, 0) >= 0
    AND coalesce(hospital_expense_deductible, 0) >= 0
    AND coalesce(outpatient_surgery_deductible, 0) >= 0
    AND coalesce(daily_hospital_benefit, 0) >= 0
  )
);

-- 比較頁一次查好幾款商品的計畫
CREATE INDEX IF NOT EXISTS idx_benefit_plans_product
  ON public.insurance_product_benefit_plans (product_id, plan_order);

COMMENT ON TABLE public.insurance_product_benefit_plans IS '實支實付理賠限額：每款商品每個計畫一筆（D14，全景地圖 4-K）';
COMMENT ON COLUMN public.insurance_product_benefit_plans.hospital_expense_includes_surgery IS '住院醫療費用限額是否包含手術費（國泰、南山多為包含）';
COMMENT ON COLUMN public.insurance_product_benefit_plans.verified_at IS '沛沛依條款抽查核對通過的時間';

-- 權限（RLS）：登入者只能讀；寫入只靠 SQL 匯入（SQL Editor 以管理者身分執行，會略過 RLS）
ALTER TABLE public.insurance_product_benefit_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Benefit plans readable by authenticated" ON public.insurance_product_benefit_plans;
CREATE POLICY "Benefit plans readable by authenticated"
  ON public.insurance_product_benefit_plans FOR SELECT
  TO authenticated
  USING (true);

REVOKE ALL ON public.insurance_product_benefit_plans FROM anon, authenticated;
GRANT SELECT ON public.insurance_product_benefit_plans TO authenticated;
