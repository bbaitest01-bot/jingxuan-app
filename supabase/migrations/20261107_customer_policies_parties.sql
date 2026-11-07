-- ============================================================================
-- 主管回饋：保單的要保人、被保險人、受益人（2026-11-07 沛沛確認模型圖）
--
-- 設計：不存姓名、身分證字號，只記「是哪一位客戶」（指向 customers.id），姓名改從客戶資料讀
--   policyholder_customer_id 要保人（出錢的人）
--   insured_customer_id      被保險人（保障的對象）；健檢算在這個人身上
--   beneficiary_customer_id  受益人是客戶時
--   beneficiary_text         受益人不是客戶時直接寫（例：法定繼承人）
-- 沒填（NULL）＝要保人、被保險人都是這張保單掛的客戶（customer_id）自己，舊資料不受影響
-- 客戶被刪掉時這幾格變回 NULL（ON DELETE SET NULL），保單不會跟著被刪
--
-- 權限：沿用「Agents can manage own customer policies」（只能管自己名下客戶的保單）；
--   另加觸發程序：三個人只能指向「同一位業務員名下」的客戶，不能選到別人的客戶
-- 可重複執行
-- ============================================================================

ALTER TABLE public.customer_policies
  ADD COLUMN IF NOT EXISTS policyholder_customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS insured_customer_id      UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS beneficiary_customer_id  UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS beneficiary_text         TEXT;

-- 客戶頁「保障我的保單」：用被保險人找保單
CREATE INDEX IF NOT EXISTS customer_policies_insured_customer_id_idx
  ON public.customer_policies (insured_customer_id)
  WHERE insured_customer_id IS NOT NULL;
-- 外鍵欄位都加索引（客戶被刪時要找有哪些保單指向他）
CREATE INDEX IF NOT EXISTS customer_policies_policyholder_customer_id_idx
  ON public.customer_policies (policyholder_customer_id)
  WHERE policyholder_customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS customer_policies_beneficiary_customer_id_idx
  ON public.customer_policies (beneficiary_customer_id)
  WHERE beneficiary_customer_id IS NOT NULL;

-- 三個人必須和保單掛的客戶屬於同一位業務員
CREATE OR REPLACE FUNCTION public.check_customer_policy_parties()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  owner_profile_id UUID;
  party_id UUID;
BEGIN
  SELECT profile_id INTO owner_profile_id FROM public.customers WHERE id = NEW.customer_id;
  FOREACH party_id IN ARRAY ARRAY[NEW.policyholder_customer_id, NEW.insured_customer_id, NEW.beneficiary_customer_id]
  LOOP
    IF party_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.customers WHERE id = party_id AND profile_id = owner_profile_id
    ) THEN
      RAISE EXCEPTION '保單的要保人、被保險人、受益人只能選自己名下的客戶';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS customer_policies_check_parties ON public.customer_policies;
CREATE TRIGGER customer_policies_check_parties
  BEFORE INSERT OR UPDATE OF policyholder_customer_id, insured_customer_id, beneficiary_customer_id, customer_id
  ON public.customer_policies
  FOR EACH ROW
  EXECUTE FUNCTION public.check_customer_policy_parties();

COMMENT ON COLUMN public.customer_policies.policyholder_customer_id IS '要保人（出錢的人）的客戶 id；空值＝保單掛的客戶自己';
COMMENT ON COLUMN public.customer_policies.insured_customer_id      IS '被保險人（保障的對象）的客戶 id；空值＝保單掛的客戶自己；健檢算在這個人身上';
COMMENT ON COLUMN public.customer_policies.beneficiary_customer_id  IS '受益人是客戶時的客戶 id';
COMMENT ON COLUMN public.customer_policies.beneficiary_text         IS '受益人不是客戶時直接寫（例：法定繼承人）';
