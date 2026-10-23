-- ============================================================================
-- 第 5 階段選項 A：客戶保單有效／已失效（問題 C6、D8；測試 C-18、D-10）
-- 日期：2026-10-23
--
-- 設計見全景地圖 4-I（2026-10-23 沛沛確認）：
--   customer_policies 加 status：active 有效／lapsed 已失效（畫面名稱「有效保單／已失效保單」）
--   新增保單預設有效；已失效的保單不算進客戶的理賠總額
--   不加失效日期（第一版不做，之後若加只放在客戶完整頁）
-- 權限：沿用「Agents can manage own customer policies」（只能管自己名下客戶的保單），不新增政策
-- 可重複執行：欄位、限制都先檢查是否存在
-- ============================================================================

ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_status_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_status_check CHECK (status IN ('active', 'lapsed'));
  END IF;
END
$$;

COMMENT ON COLUMN public.customer_policies.status IS '保單狀態：active 有效／lapsed 已失效（4-I）';
