-- ============================================================================
-- 3-C：個人帳號「名片」欄位存進資料庫（問題 A1、A2）
-- 日期：2026-10-13
--
-- 原因：個人帳號頁的名片有 7 項資料在 profiles 表沒有欄位，連線模式下按儲存
--       不會送進資料庫，重新整理就消失。
-- 做法：只在既有的 public.profiles 表「加欄位」，不新增資料表。
-- 權限：沿用既有 RLS「Profiles are updatable by owner or admin/dev」
--       （只能改自己的資料，主管／開發者例外），新欄位一樣受保護，不需新增政策。
--       角色、帳號狀態、團隊的防竄改 trigger 不受影響。
-- 可重複執行：欄位用 IF NOT EXISTS，限制條件先檢查是否已存在。
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS line_id           TEXT,                                  -- LINE ID
  ADD COLUMN IF NOT EXISTS license_no        TEXT,                                  -- 業務員登錄字號
  ADD COLUMN IF NOT EXISTS honor_title       TEXT,                                  -- 榮譽頭銜（例：首席理財大師）
  ADD COLUMN IF NOT EXISTS badges            TEXT[] NOT NULL DEFAULT '{}',          -- 名片上的證照／榮譽徽章
  ADD COLUMN IF NOT EXISTS card_theme        TEXT   NOT NULL DEFAULT 'system_primary', -- 名片配色主題
  ADD COLUMN IF NOT EXISTS card_custom_color TEXT,                                  -- 自訂配色時的顏色（#RRGGBB）
  ADD COLUMN IF NOT EXISTS qr_code_url       TEXT;                                  -- 名片上的 QR Code 圖片網址（存在 avatars 儲存空間）

COMMENT ON COLUMN public.profiles.line_id IS '名片：LINE ID';
COMMENT ON COLUMN public.profiles.license_no IS '名片：業務員登錄字號';
COMMENT ON COLUMN public.profiles.honor_title IS '名片：榮譽頭銜';
COMMENT ON COLUMN public.profiles.badges IS '名片：證照與榮譽徽章（最多 20 個）';
COMMENT ON COLUMN public.profiles.card_theme IS '名片：配色主題 system_primary／dark_gold／cyan_slate／emerald／custom_color';
COMMENT ON COLUMN public.profiles.card_custom_color IS '名片：自訂配色（#RRGGBB），card_theme = custom_color 時使用';
COMMENT ON COLUMN public.profiles.qr_code_url IS '名片：QR Code 圖片公開網址（avatars 儲存空間，自己的資料夾）';

-- 長度與格式限制：避免存入異常資料（PostgreSQL 沒有 ADD CONSTRAINT IF NOT EXISTS，所以先檢查）
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_card_text_length_check'
                 AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_card_text_length_check CHECK (
      (line_id IS NULL OR char_length(line_id) <= 50)
      AND (license_no IS NULL OR char_length(license_no) <= 50)
      AND (honor_title IS NULL OR char_length(honor_title) <= 30)
      AND (qr_code_url IS NULL OR char_length(qr_code_url) <= 500)
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_badges_count_check'
                 AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_badges_count_check CHECK (
      cardinality(badges) <= 20
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_card_theme_check'
                 AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_card_theme_check CHECK (
      card_theme IN ('system_primary', 'dark_gold', 'cyan_slate', 'emerald', 'custom_color')
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_card_custom_color_check'
                 AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_card_custom_color_check CHECK (
      card_custom_color IS NULL OR card_custom_color ~ '^#[0-9A-Fa-f]{6}$'
    );
  END IF;
END $$;
