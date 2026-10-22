-- ============================================================================
-- 5-2a：真實保險商品目錄（問題 D1、D2、D5）
-- 日期：2026-10-23
--
-- 設計見全景地圖 4-H（2026-10-23 沛沛確認）：
--   1. insurance_products：第一層商品目錄（公司、商品名稱、代碼、文號、條款連結、來源）
--      資料來自國泰、富邦、南山官網「資訊公開 → 保險商品」，只收個人保險
--   2. product_crawl_runs：每次抓取的紀錄（成功／失敗、筆數），畫面顯示資料更新日期用
-- 寫入方式：GitHub 排程跑抓取程式 → 雲端函式 import-product-catalog 用 service role 寫入。
-- 權限：登入者只能讀；沒有任何新增／修改／刪除政策，App 與未登入者都不能寫。
-- 價格、理賠上限等第二層比價欄位不放這裡，之後另開資料表用 insurance_products.id 連結。
-- 可重複執行：表、索引用 IF NOT EXISTS；政策、觸發器先 DROP IF EXISTS。
-- ============================================================================

-- 1. 商品目錄
CREATE TABLE IF NOT EXISTS public.insurance_products (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_code      TEXT        NOT NULL,
  company_name      TEXT        NOT NULL,
  product_code      TEXT,
  product_name      TEXT        NOT NULL,
  product_kind      TEXT        NOT NULL DEFAULT 'main',
  insurance_type    TEXT,
  source_category   TEXT        NOT NULL DEFAULT '',
  approval_date     DATE,
  approval_number   TEXT,
  approval_history  TEXT,
  clause_url        TEXT,
  source_url        TEXT        NOT NULL,
  first_seen_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- 同一家公司的商品以名稱為準（有些商品官網找不到代碼）
  CONSTRAINT insurance_products_company_product_unique UNIQUE (company_code, product_name),
  -- 公司代號只用小寫英文（cathay、fubon、nanshan），之後擴充其他家不用改規則
  CONSTRAINT insurance_products_company_code_check CHECK (company_code ~ '^[a-z]{2,30}$'),
  -- main 主約／rider 附約／endorsement 批註或附加條款
  CONSTRAINT insurance_products_kind_check CHECK (product_kind IN ('main', 'rider', 'endorsement')),
  -- 險種代號，畫面上再翻成中文；依商品名稱關鍵字判斷，判斷不出來就是 other
  CONSTRAINT insurance_products_type_check CHECK (
    insurance_type IS NULL OR insurance_type IN (
      'medical', 'cancer', 'critical_illness', 'long_term_care',
      'accident', 'life', 'annuity', 'investment', 'other'
    )
  ),
  CONSTRAINT insurance_products_name_length CHECK (char_length(product_name) BETWEEN 1 AND 200),
  -- 連結只能是 https 網址，避免存進 javascript: 之類的內容被畫面點開
  CONSTRAINT insurance_products_clause_url_check CHECK (clause_url IS NULL OR clause_url ~ '^https://'),
  CONSTRAINT insurance_products_source_url_check CHECK (source_url ~ '^https://')
);

COMMENT ON TABLE public.insurance_products IS '真實保險商品目錄（5-2a）：來自各保險公司官網資訊公開，只由伺服器寫入，登入者唯讀';
COMMENT ON COLUMN public.insurance_products.product_code IS '官網條款檔名或網頁資料裡的商品代碼；找不到就空';
COMMENT ON COLUMN public.insurance_products.approval_history IS '核准／核備／備查文號原文（含歷次修正，多行）';
COMMENT ON COLUMN public.insurance_products.last_seen_at IS '最後一次在官網清單看到；落後最近成功抓取兩次以上，畫面標示可能已停售';

-- 公司篩選、險種篩選用（商品只有一千多筆，名稱搜尋用一般 ilike 即可，不另開 pg_trgm）
CREATE INDEX IF NOT EXISTS idx_insurance_products_company
  ON public.insurance_products (company_code);
CREATE INDEX IF NOT EXISTS idx_insurance_products_type
  ON public.insurance_products (insurance_type);

-- 修改時自動更新 updated_at（沿用共用函式）
DROP TRIGGER IF EXISTS trigger_update_insurance_products_timestamp ON public.insurance_products;
CREATE TRIGGER trigger_update_insurance_products_timestamp
  BEFORE UPDATE ON public.insurance_products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 2. 抓取紀錄
CREATE TABLE IF NOT EXISTS public.product_crawl_runs (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_code   TEXT        NOT NULL,
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at    TIMESTAMPTZ,
  status         TEXT        NOT NULL,
  product_count  INTEGER     NOT NULL DEFAULT 0,
  error_message  TEXT,
  CONSTRAINT product_crawl_runs_company_code_check CHECK (company_code ~ '^[a-z]{2,30}$'),
  CONSTRAINT product_crawl_runs_status_check CHECK (status IN ('success', 'failed')),
  CONSTRAINT product_crawl_runs_count_check CHECK (product_count >= 0),
  CONSTRAINT product_crawl_runs_error_length CHECK (error_message IS NULL OR char_length(error_message) <= 1000)
);

COMMENT ON TABLE public.product_crawl_runs IS '商品目錄每次抓取的紀錄（5-2a）：顯示資料更新日期、找出哪家抓取失敗';

-- 各公司最近一次抓取（畫面顯示更新日期）
CREATE INDEX IF NOT EXISTS idx_product_crawl_runs_company_started
  ON public.product_crawl_runs (company_code, started_at DESC);

-- 3. 權限（RLS）：登入者只能讀，寫入只靠 service role（會略過 RLS）
ALTER TABLE public.insurance_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_crawl_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Insurance products readable by authenticated" ON public.insurance_products;
CREATE POLICY "Insurance products readable by authenticated"
  ON public.insurance_products FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Product crawl runs readable by authenticated" ON public.product_crawl_runs;
CREATE POLICY "Product crawl runs readable by authenticated"
  ON public.product_crawl_runs FOR SELECT
  TO authenticated
  USING (true);

-- 沒有 INSERT／UPDATE／DELETE 政策；再把資料表權限收緊，未登入者完全不能碰
REVOKE ALL ON public.insurance_products FROM anon, authenticated;
REVOKE ALL ON public.product_crawl_runs FROM anon, authenticated;
GRANT SELECT ON public.insurance_products TO authenticated;
GRANT SELECT ON public.product_crawl_runs TO authenticated;
