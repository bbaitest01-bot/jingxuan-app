-- ============================================================================
-- 4-3c：客戶狀態 ✔／△／✖（問題 C5，手動設定）
-- 日期：2026-10-14
--
-- 意思（2026-10-14 沛沛確認；之後專案拜訪結果 P3 也用同一套）：
--   positive    ✔ 有意願／已成交
--   considering △ 考慮中／待跟進
--   negative    ✖ 無意願／暫不考慮
--   NULL          未設定（新客戶預設）
-- 欄位名稱不用 status：程式裡已有舊的 status 用法（草稿客戶），避免撞名。
-- 權限：沿用 customers 既有 RLS，不需新增政策。
-- 可重複執行：欄位用 IF NOT EXISTS，限制條件先檢查是否存在。
-- ============================================================================

ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS client_status TEXT;

COMMENT ON COLUMN public.customers.client_status IS '客戶狀態：positive ✔ 有意願／已成交、considering △ 考慮中／待跟進、negative ✖ 無意願；NULL＝未設定（4-3c）';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customers_client_status_check'
                 AND conrelid = 'public.customers'::regclass) THEN
    ALTER TABLE public.customers ADD CONSTRAINT customers_client_status_check CHECK (
      client_status IS NULL OR client_status IN ('positive', 'considering', 'negative')
    );
  END IF;
END $$;
