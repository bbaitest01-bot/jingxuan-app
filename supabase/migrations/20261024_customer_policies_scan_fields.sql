-- ============================================================================
-- 第 5 階段選項 E：掃描保單第一版（問題 D6、D7）
-- 日期：2026-10-24
--
-- 設計見全景地圖 4-J（2026-10-24 沛沛確認）：
--   一個商品存一筆（存法 A）；同一份保單的主約、附約用 policy_group_id 串起來
--   目錄找不到的商品照樣存（policy_clause_id 本來就可以是空的），畫面再標示
--   不保存保單照片，也不存要保人、被保險人、身分證字號等個資，只存商品相關欄位
-- 權限：沿用「Agents can manage own customer policies」（只能管自己名下客戶的保單），不新增政策
-- 可重複執行：欄位、限制都先檢查是否存在
-- ============================================================================

ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS policy_group_id UUID,
  ADD COLUMN IF NOT EXISTS policy_number   TEXT,
  ADD COLUMN IF NOT EXISTS coverage_role   TEXT,
  ADD COLUMN IF NOT EXISTS plan_or_amount  TEXT,
  ADD COLUMN IF NOT EXISTS effective_date  DATE,
  ADD COLUMN IF NOT EXISTS premium         INTEGER,
  ADD COLUMN IF NOT EXISTS source          TEXT NOT NULL DEFAULT 'manual';

DO $$
BEGIN
  -- 主約／附約只能是 main、rider（手動加入的舊資料可以是空的）
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_coverage_role_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_coverage_role_check
      CHECK (coverage_role IS NULL OR coverage_role IN ('main', 'rider'));
  END IF;

  -- 資料來源只能是手動或掃描
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_source_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_source_check
      CHECK (source IN ('manual', 'scan'));
  END IF;

  -- 保費不能是負數
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'customer_policies_premium_check'
  ) THEN
    ALTER TABLE public.customer_policies
      ADD CONSTRAINT customer_policies_premium_check
      CHECK (premium IS NULL OR premium >= 0);
  END IF;
END
$$;

-- 整份保單一起改狀態時，用 policy_group_id 找出同一份的商品
CREATE INDEX IF NOT EXISTS customer_policies_policy_group_id_idx
  ON public.customer_policies (policy_group_id)
  WHERE policy_group_id IS NOT NULL;

COMMENT ON COLUMN public.customer_policies.policy_group_id IS '同一份保單的主約、附約共用同一個值（4-J）';
COMMENT ON COLUMN public.customer_policies.policy_number   IS '保單號碼（可空）';
COMMENT ON COLUMN public.customer_policies.coverage_role   IS '主約 main／附約 rider（可空）';
COMMENT ON COLUMN public.customer_policies.plan_or_amount  IS '計畫或保額，照保單上的文字存（例：計畫三、50 萬元）';
COMMENT ON COLUMN public.customer_policies.effective_date  IS '契約生效日（可空）';
COMMENT ON COLUMN public.customer_policies.premium         IS '保費（新臺幣元，照保單上的金額；可空）';
COMMENT ON COLUMN public.customer_policies.source          IS '資料來源：manual 手動加入／scan 掃描保單';
