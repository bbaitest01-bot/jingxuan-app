-- ============================================================================
-- 主管回饋：保單欄位補齊（2026-11-07 沛沛確認模型圖）
--
-- 1. payment_frequency：繳別（年繳／半年繳／季繳／月繳／躉繳）；搭配既有 premium（每期保費）算一年保費
-- 2. status 細分：原本只有 active 有效／lapsed 已失效，改成六種
--      有保障：active 有效、reduced_paid_up 減額繳清、extended_term 展期定期
--      沒保障：lapsed 停效（可復效）、surrendered 解約、matured 滿期
--    舊資料的 lapsed 直接當「停效」（英文 lapsed 本來就是停效）
-- 3. has_policy_loan：有保單貸款（不是狀態，是有效保單上的加註）
-- 4. reduced_coverage_amount：減額繳清後的新保額（健檢改用這個數字）
-- 權限：沿用「Agents can manage own customer policies」（只能管自己名下客戶的保單），只加欄位，不新增政策
-- 可重複執行：欄位、限制都先檢查是否存在
-- ============================================================================

ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS payment_frequency        TEXT,
  ADD COLUMN IF NOT EXISTS has_policy_loan          BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reduced_coverage_amount  INTEGER;

-- 狀態限制：先拿掉舊的（只有兩種），再加上六種
ALTER TABLE public.customer_policies
  DROP CONSTRAINT IF EXISTS customer_policies_status_check;
ALTER TABLE public.customer_policies
  ADD CONSTRAINT customer_policies_status_check CHECK (status IN
    ('active', 'reduced_paid_up', 'extended_term', 'lapsed', 'surrendered', 'matured'));

DO $$
BEGIN
  -- 繳別只能是這五種（沒填可以是空的）
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_payment_frequency_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_payment_frequency_check
      CHECK (payment_frequency IS NULL OR payment_frequency IN ('annual', 'semiannual', 'quarterly', 'monthly', 'single'));
  END IF;
  -- 新保額不能是負數
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_reduced_coverage_amount_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_reduced_coverage_amount_check
      CHECK (reduced_coverage_amount IS NULL OR reduced_coverage_amount >= 0);
  END IF;
END
$$;

COMMENT ON COLUMN public.customer_policies.status IS
  '保單狀態：active 有效／reduced_paid_up 減額繳清／extended_term 展期定期（以上有保障）；lapsed 停效／surrendered 解約／matured 滿期（以上沒保障）';
COMMENT ON COLUMN public.customer_policies.payment_frequency IS
  '繳別：annual 年繳／semiannual 半年繳／quarterly 季繳／monthly 月繳／single 躉繳；空值＝還沒填';
COMMENT ON COLUMN public.customer_policies.has_policy_loan IS '有保單貸款（保單仍有效，只是借了保單價值準備金）';
COMMENT ON COLUMN public.customer_policies.reduced_coverage_amount IS '減額繳清後的新保額（元）；只有 status = reduced_paid_up 時使用';
