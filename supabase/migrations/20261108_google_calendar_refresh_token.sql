-- ============================================================================
-- L4 再次發生：Google 日曆通行證 1 小時就過期，沒辦法自動換新
-- 日期：2026-11-08（設計見全景地圖 4-P）
--
-- 用 Google 登入時，Google 會給：
--   - 通行證（access token）：約 1 小時過期，App 拿來推送行程
--   - 換證單（refresh token）：可以拿去換新的通行證，以前沒有存下來
-- 這次把換證單存進資料庫，由雲端函式 refresh-google-token 幫忙換新的通行證。
--
-- 安全：
--   - 換證單等於「長期進出這個人的 Google 日曆的鑰匙」，App（包括本人）都讀不到，
--     只有雲端函式用 service role 讀
--   - App 只能透過 save_google_refresh_token() 存「自己的」換證單
-- 可重複執行：表用 IF NOT EXISTS；函式用 CREATE OR REPLACE。
-- ============================================================================

-- 1. 換證單資料表（一個人一列）
CREATE TABLE IF NOT EXISTS public.google_calendar_credentials (
  profile_id    UUID        PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  refresh_token TEXT        NOT NULL,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT google_calendar_credentials_token_length CHECK (char_length(refresh_token) BETWEEN 10 AND 2000)
);

COMMENT ON TABLE public.google_calendar_credentials IS
  'Google 日曆換證單（L4）：只有雲端函式 refresh-google-token 用 service role 讀；App 只能用 save_google_refresh_token() 存自己的';

-- 2. 權限：開 RLS、不建任何政策、收回所有權限 → 登入者與未登入者都不能讀寫
ALTER TABLE public.google_calendar_credentials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.google_calendar_credentials FROM anon, authenticated;

-- 3. 存自己的換證單（登入後 App 呼叫；有舊的就換成新的）
CREATE OR REPLACE FUNCTION public.save_google_refresh_token(p_refresh_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id UUID := auth.uid();
BEGIN
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '請先登入';
  END IF;
  IF p_refresh_token IS NULL OR char_length(trim(p_refresh_token)) < 10 THEN
    RAISE EXCEPTION '換證單格式不正確';
  END IF;

  INSERT INTO public.google_calendar_credentials (profile_id, refresh_token, updated_at)
  VALUES (v_profile_id, trim(p_refresh_token), now())
  ON CONFLICT (profile_id)
  DO UPDATE SET refresh_token = EXCLUDED.refresh_token, updated_at = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.save_google_refresh_token(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_google_refresh_token(TEXT) TO authenticated;
