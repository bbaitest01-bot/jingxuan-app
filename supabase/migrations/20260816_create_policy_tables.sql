-- ============================================================================
-- D13：補上 policy_clauses、customer_policies 的「建立資料表」紀錄
-- 撰寫日期：2026-10-23（5-2a）
--
-- 為什麼檔名是 20260816：
--   這兩張表當初是直接在 Supabase 後台建立的，repo 沒有建立紀錄。
--   20260817、20260818 的 migration 會修改這兩張表，所以建立紀錄必須排在它們前面，
--   新環境（先跑 supabase_schema.sql，再依檔名順序跑 migrations）才能從頭重建。
--
-- 內容依 2026-10-23 線上唯讀查詢的實際結構撰寫（欄位、預設值、限制）。
-- 線上已經有這兩張表：全部用 IF NOT EXISTS，在線上執行不會有任何改變。
-- 權限政策由 20260818_database_hardening_final.sql 建立，這裡只先開啟 RLS。
-- ============================================================================

-- 1. 商品條款庫（舊表；2026-10 時全是假資料產生器產生的，5-2b 會清除）
CREATE TABLE IF NOT EXISTS public.policy_clauses (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_name   TEXT        NOT NULL,
  company_name   TEXT        NOT NULL,
  category       TEXT        NOT NULL,
  waiting_days   TEXT,
  tags           TEXT[],
  room_limit     TEXT,
  surgery_limit  TEXT,
  misc_limit     TEXT,
  raw_pdf_url    TEXT,
  benefits_json  JSONB       DEFAULT '{}'::jsonb,
  crawled_at     TIMESTAMPTZ DEFAULT now(),
  created_at     TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_policy_clauses_company_product UNIQUE (company_name, product_name)
);

ALTER TABLE public.policy_clauses ENABLE ROW LEVEL SECURITY;

-- 2. 客戶已投保的保單（商品資料是複製一份存在這裡，policy_clause_id 只是文字、沒有外鍵）
CREATE TABLE IF NOT EXISTS public.customer_policies (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id       UUID        NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  policy_clause_id  TEXT,
  product_name      TEXT        NOT NULL,
  company_name      TEXT        NOT NULL,
  category          TEXT        DEFAULT '實支實付醫療險',
  room_limit        TEXT        DEFAULT '2,000 元/日',
  surgery_limit     TEXT        DEFAULT '150,000 元',
  misc_limit        TEXT        DEFAULT '120,000 元',
  raw_pdf_url       TEXT,
  benefits_json     JSONB       DEFAULT '{}'::jsonb,
  enrolled_at       TIMESTAMPTZ DEFAULT now(),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.customer_policies ENABLE ROW LEVEL SECURITY;
