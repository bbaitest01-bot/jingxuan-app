-- ============================================================================
-- 第 5 階段選項 E 修正：掃描保單的保費幣別（2026-10-24 沛沛手機實測發現）
--
-- 原因：南山美元保單的主約保費「USD 4,215」被存成 4215、畫面顯示「4215 元」
-- 做法：customer_policies 加 premium_currency（三個大寫英文字母的幣別代碼，例：TWD、USD）；
--       空值視為新臺幣（舊資料、手動加入的保單都沒有保費，維持空值）
-- 權限：沿用「Agents can manage own customer policies」，不新增政策
-- 可重複執行：欄位、限制都先檢查是否存在
-- ============================================================================

ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS premium_currency TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_premium_currency_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_premium_currency_check
      CHECK (premium_currency IS NULL OR premium_currency ~ '^[A-Z]{3}$');
  END IF;
END
$$;

COMMENT ON COLUMN public.customer_policies.premium_currency IS '保費幣別代碼（TWD、USD…）；空值視為新臺幣';
