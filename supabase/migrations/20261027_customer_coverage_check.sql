-- ============================================================================
-- 第 5 階段 D：保單健檢（全景地圖 4-L，2026-10-27 沛沛確認）
--
-- 1. insurance_product_coverage_overrides：名稱看不出來、讀條款判斷的 54 款商品保障類別
--    （由 tool/coverage_categories/classify_coverage.py 整理，理由寫在 reason）
-- 2. insurance_product_coverage（view）：每款商品的保障類別＝人工判斷 → 名稱規則；
--    規則和 classify_coverage.py 的 classify_by_name() 相同，每週新抓到的商品也會自動分類；
--    判斷不出來是 NULL（app 請業務員自己選）
-- 3. customer_policies 加 coverage_category（業務員改過才有）、coverage_amount（保額）、benefit_plan_id（實支選的計畫）
-- 4. customer_coverage_targets：每位客戶每項保障的目標（業務員自己設定）
-- 權限：商品分類登入者唯讀；客戶目標只能管自己名下客戶（同 customer_policies）
-- 可重複執行
-- ============================================================================

-- 保障類別：life 壽險／accident 意外／reimbursement 實支實付／daily_hospital 住院日額／surgery 手術／
--          cancer 癌症／critical_illness 重大傷病／long_term_care 長照／none 不列入健檢

-- 1. 讀條款判斷的商品
CREATE TABLE IF NOT EXISTS public.insurance_product_coverage_overrides (
  company_code       TEXT NOT NULL,
  product_name       TEXT NOT NULL,
  coverage_category  TEXT NOT NULL,
  reason             TEXT,
  PRIMARY KEY (company_code, product_name),
  CONSTRAINT coverage_overrides_category_check CHECK (coverage_category IN
    ('life', 'accident', 'reimbursement', 'daily_hospital', 'surgery', 'cancer', 'critical_illness', 'long_term_care', 'none'))
);

INSERT INTO public.insurance_product_coverage_overrides (company_code, product_name, coverage_category, reason) VALUES
  ('cathay', '國泰人壽真心安住院醫療終身保險(外溢型)', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽真漾心安住院醫療終身保險(外溢型)', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽康泰無憂PLUS住院醫療終身健康保險（外溢型）', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽真安安醫療終身保險(外溢型)', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽輕漾心安住院醫療終身健康保險(外溢型)', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽樂心安住院醫療定期保險(外溢型)', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽享醫靠醫療終身保險', 'daily_hospital', '條款關鍵字'),
  ('cathay', '國泰人壽自由配一年定期健康保險附約（外溢型）', 'long_term_care', '條款關鍵字'),
  ('cathay', '國泰人壽新真大心PLUS住院醫療健康保險附約（外溢型）', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽全鑫如意保險', 'accident', '條款給付項目：意外傷害身故、失能為主（名稱看不出險種）'),
  ('fubon', '富邦人壽新安心寶倍終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽真康泰終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽金享福保本終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽全心照護終身健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽喜轉樂活終身健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽喜轉健活終身健康保險', 'daily_hospital', '條款給付項目：住院醫療（日額）、出院療養、手術'),
  ('fubon', '富邦人壽新鍾愛寶倍終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽新吉安終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽智糖人生定期健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽增守護健康保險附約', 'surgery', '條款給付項目只有手術醫療、特定處置（關鍵字誤判成癌症）'),
  ('fubon', '富邦人壽愛有醫靠醫療定期健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽日日心安一年期住院醫療健康保險附約', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽安心在家一年期住院醫療健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽樂活常青終身健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽樂齡守護定期健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽心福一生終身健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽網投日安心定期健康保險', 'daily_hospital', '條款關鍵字'),
  ('fubon', '富邦人壽金安守護終身健康保險', 'surgery', '條款給付項目：手術醫療、特定處置、身故（關鍵字誤判成癌症）'),
  ('fubon', '富邦人壽金醫靠健康保險附約', 'none', '條款給付項目只有醫材補助，不屬八大保障'),
  ('fubon', '富邦人壽換然醫新定期健康保險', 'none', '條款給付項目：眼睛、耳朵、關節醫療，不屬八大保障'),
  ('fubon', '富邦人壽樂齡金安定期健康保險', 'daily_hospital', '條款給付項目：住院醫療（日額）、加護病房、手術'),
  ('fubon', '富邦人壽網投低頭族定期健康保險附約', 'surgery', '條款關鍵字'),
  ('fubon', '富邦人壽心動守護定期健康保險', 'none', '條款給付項目：醫材補助、無理賠回饋，不屬八大保障'),
  ('fubon', '富邦人壽憶心相守終身健康保險', 'long_term_care', '條款給付項目：輕度、中重度失智保險金'),
  ('fubon', '富邦人壽樂享護定期健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽樂長愛定期健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽樂安馨定期健康保險', 'critical_illness', '條款關鍵字'),
  ('fubon', '富邦人壽樂齡滿溢保險', 'accident', '條款給付項目：意外骨折、意外身故、失能'),
  ('nanshan', '南山人壽好安定住院暨在宅急症照護一年期健康保險', 'none', '條款給付項目：住院關懷、在宅急症照護（每次一筆），不屬八大保障'),
  ('nanshan', '南山人壽心心相惜生活習慣健康保險', 'critical_illness', '條款關鍵字'),
  ('nanshan', '南山人壽長青安溢醫療定期健康保險', 'daily_hospital', '條款給付項目：住院日額保險金為主（關鍵字誤判成癌症）'),
  ('nanshan', '南山人壽樂享健康2健康保險附約', 'critical_illness', '條款關鍵字'),
  ('nanshan', '南山人壽優樂康護短期照顧終身健康保險', 'long_term_care', '條款：短期照顧，依單位日額給付'),
  ('nanshan', '南山人壽大樂選利率變動型還本保險(定期給付型)', 'life', '條款給付項目：生存還本、身故、完全失能（以身故保障計）'),
  ('nanshan', '南山人壽增享心安保險', 'cancer', '條款給付項目：初期、輕度、重度癌症保險金'),
  ('nanshan', '南山人壽保滿溢醫療終身保險', 'daily_hospital', '條款關鍵字'),
  ('nanshan', '南山人壽樂活洋溢醫療終身保險', 'daily_hospital', '條款關鍵字'),
  ('nanshan', '南山人壽溢心守護2醫療保險', 'daily_hospital', '條款給付項目：住院日額、加護病房、手術、處置'),
  ('nanshan', '南山人壽全心溢靠2醫療保險', 'critical_illness', '條款關鍵字'),
  ('nanshan', '南山人壽樂健康祥定期健康保險', 'critical_illness', '條款關鍵字'),
  ('nanshan', '南山人壽溢帆風順2保險', 'life', '條款給付項目：身故、完全失能，另含意外保障（以身故保障計）'),
  ('nanshan', '南山人壽青春動起來保險', 'accident', '條款給付項目：意外身故、失能、骨折'),
  ('nanshan', '南山人壽穩助糖醫療保險', 'surgery', '條款關鍵字'),
  ('nanshan', '南山人壽Hold助糖定期醫療保險', 'daily_hospital', '條款給付項目：住院日額、手術、門診')
ON CONFLICT (company_code, product_name) DO UPDATE
  SET coverage_category = EXCLUDED.coverage_category, reason = EXCLUDED.reason;

ALTER TABLE public.insurance_product_coverage_overrides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Coverage overrides readable by authenticated" ON public.insurance_product_coverage_overrides;
CREATE POLICY "Coverage overrides readable by authenticated"
  ON public.insurance_product_coverage_overrides FOR SELECT TO authenticated USING (true);
REVOKE ALL ON public.insurance_product_coverage_overrides FROM anon, authenticated;
GRANT SELECT ON public.insurance_product_coverage_overrides TO authenticated;

-- 2. 每款商品的保障類別（security_invoker：用查詢者自己的權限讀底下的表）
CREATE OR REPLACE VIEW public.insurance_product_coverage
WITH (security_invoker = true) AS
SELECT
  p.id AS product_id,
  CASE
    WHEN o.coverage_category IS NOT NULL THEN o.coverage_category
    WHEN p.product_kind = 'endorsement' THEN 'none'
    WHEN EXISTS (SELECT 1 FROM public.insurance_product_benefit_plans b WHERE b.product_id = p.id) THEN 'reimbursement'
    WHEN p.product_name ~ '豁免' THEN 'none'
    WHEN p.insurance_type IN ('investment', 'annuity') THEN 'none'
    WHEN p.product_name ~ '海外|旅行|旅平|暢遊' THEN 'none'
    -- 「傷害失能」是意外險（一次給付），不是長照；2026-10-27 沛沛測試發現
    WHEN p.insurance_type = 'long_term_care' OR (p.product_name ~ '失能' AND p.product_name !~ '傷害|意外') THEN 'long_term_care'
    WHEN p.insurance_type = 'cancer' THEN 'cancer'
    WHEN p.insurance_type = 'critical_illness' OR p.product_name ~ '傷病' THEN 'critical_illness'
    WHEN p.insurance_type = 'accident' AND p.product_name ~ '醫療' THEN 'none'
    WHEN p.insurance_type = 'accident' THEN 'accident'
    WHEN p.insurance_type = 'medical' AND p.product_name ~ '傷害|意外' THEN 'none'
    WHEN p.insurance_type = 'medical' AND p.product_name ~ '手術|處置' AND p.product_name !~ '住院醫療' THEN 'surgery'
    WHEN p.insurance_type = 'medical' AND p.product_name ~ '日額|定額' THEN 'daily_hospital'
    WHEN p.insurance_type = 'medical' THEN NULL
    WHEN p.insurance_type = 'life' OR p.product_name ~ '外幣保險|壽險' THEN 'life'
    ELSE NULL
  END AS coverage_category
FROM public.insurance_products p
LEFT JOIN public.insurance_product_coverage_overrides o
  ON o.company_code = p.company_code AND o.product_name = p.product_name;

GRANT SELECT ON public.insurance_product_coverage TO authenticated;

-- 3. 客戶保單：保障類別（業務員改過才有值）、保額、實支計畫
ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS coverage_category TEXT,
  ADD COLUMN IF NOT EXISTS coverage_amount   BIGINT,
  ADD COLUMN IF NOT EXISTS benefit_plan_id   UUID REFERENCES public.insurance_product_benefit_plans(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_coverage_category_check') THEN
    ALTER TABLE public.customer_policies ADD CONSTRAINT customer_policies_coverage_category_check
      CHECK (coverage_category IS NULL OR coverage_category IN
        ('life', 'accident', 'reimbursement', 'daily_hospital', 'surgery', 'cancer', 'critical_illness', 'long_term_care', 'none'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_coverage_amount_check') THEN
    ALTER TABLE public.customer_policies ADD CONSTRAINT customer_policies_coverage_amount_check
      CHECK (coverage_amount IS NULL OR coverage_amount >= 0);
  END IF;
END
$$;

COMMENT ON COLUMN public.customer_policies.coverage_category IS '業務員改過的保障類別；空值＝跟商品分類（insurance_product_coverage）';
COMMENT ON COLUMN public.customer_policies.coverage_amount IS '保額（新臺幣元；住院日額為元／日、長照為元／月）';
COMMENT ON COLUMN public.customer_policies.benefit_plan_id IS '實支實付保單選的計畫';

-- 4. 客戶保障目標（業務員依客戶需求設定）
CREATE TABLE IF NOT EXISTS public.customer_coverage_targets (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id    UUID        NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  category       TEXT        NOT NULL,
  target_amount  BIGINT      NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT coverage_targets_customer_category_unique UNIQUE (customer_id, category),
  CONSTRAINT coverage_targets_category_check CHECK (category IN
    ('life', 'accident', 'reimbursement_room', 'reimbursement_hospital', 'daily_hospital', 'surgery', 'cancer', 'critical_illness', 'long_term_care')),
  CONSTRAINT coverage_targets_amount_check CHECK (target_amount >= 0)
);

ALTER TABLE public.customer_coverage_targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Agents can manage own customer coverage targets" ON public.customer_coverage_targets;
CREATE POLICY "Agents can manage own customer coverage targets"
  ON public.customer_coverage_targets FOR ALL
  TO authenticated
  USING (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  )
  WITH CHECK (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  );
REVOKE ALL ON public.customer_coverage_targets FROM anon;

-- 檢查：各保障類別有幾款商品（NULL＝判斷不出來，app 請業務員選）
SELECT coalesce(coverage_category, '（判斷不出來）') AS category, count(*) AS product_count
FROM public.insurance_product_coverage
GROUP BY 1 ORDER BY 2 DESC;
