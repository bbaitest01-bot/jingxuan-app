-- ============================================================================
-- 4-3b：客戶性別欄位（問題 C4）
-- 日期：2026-10-14
--
-- 做法：customers 加 gender 欄位；可空（＝不填）。選項：male 男、female 女（沛沛決定）。
-- 權限：沿用 customers 既有 RLS，新欄位一樣受保護，不需新增政策。
-- 可重複執行：欄位用 IF NOT EXISTS，限制條件先檢查是否存在。
-- ============================================================================

ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS gender TEXT;

COMMENT ON COLUMN public.customers.gender IS '性別：male 男／female 女；NULL＝不填（4-3b）';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customers_gender_check'
                 AND conrelid = 'public.customers'::regclass) THEN
    ALTER TABLE public.customers ADD CONSTRAINT customers_gender_check CHECK (
      gender IS NULL OR gender IN ('male', 'female')
    );
  END IF;
END $$;
