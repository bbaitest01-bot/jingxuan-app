-- ============================================================================
-- 第 5 階段 D 第 2 層：定額型商品的給付項目（住院日額、手術、癌症、重大傷病、長照、意外）
--
-- insurance_product_benefit_items：每款商品每個給付項目一筆
--   item_key       比較表對齊用的名稱（各家同一種給付統一寫法，例：首次罹患→初次罹患）
--   item_name      條款上的原名
--   formula        怎麼算（例：保額 × 10%、日額 × 3 × 天數）；條款寫法太複雜時是 NULL，畫面顯示「依條款」
--   source_excerpt 條款原文那一句（出處）
-- 由 tool/benefit_items/extract_benefit_items.py 從條款抓出，supabase/seed/benefit_items.sql 匯入
-- 權限：登入者唯讀；寫入只靠 SQL 匯入（同 insurance_product_benefit_plans）
-- 可重複執行
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.insurance_product_benefit_items (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id      UUID        NOT NULL REFERENCES public.insurance_products(id) ON DELETE CASCADE,
  item_order      INTEGER     NOT NULL,
  item_key        TEXT        NOT NULL,
  item_name       TEXT        NOT NULL,
  formula         TEXT,
  source_excerpt  TEXT        NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT benefit_items_product_key_unique UNIQUE (product_id, item_key)
);

-- 比較頁一次查好幾款商品的項目（UNIQUE 已經建了 product_id 開頭的索引，不另建）

COMMENT ON TABLE public.insurance_product_benefit_items IS '定額型商品給付項目：每款商品每個項目一筆（第 5 階段 D 第 2 層）';
COMMENT ON COLUMN public.insurance_product_benefit_items.formula IS '怎麼算（保額 × 10% 等）；NULL＝條款寫法複雜，看原文';
COMMENT ON COLUMN public.insurance_product_benefit_items.source_excerpt IS '條款原文出處';

ALTER TABLE public.insurance_product_benefit_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Benefit items readable by authenticated" ON public.insurance_product_benefit_items;
CREATE POLICY "Benefit items readable by authenticated"
  ON public.insurance_product_benefit_items FOR SELECT
  TO authenticated
  USING (true);

REVOKE ALL ON public.insurance_product_benefit_items FROM anon, authenticated;
GRANT SELECT ON public.insurance_product_benefit_items TO authenticated;
