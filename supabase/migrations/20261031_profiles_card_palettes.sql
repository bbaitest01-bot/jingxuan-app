-- 2026-10-31 名片改成「模板＋配色」：card_theme 存「模板代碼:配色編號」，例如 classic:0、night:2
-- 舊的代碼（system_primary、dark_gold…，以及當天短暫用過的 navy、forest、wine、graphite）仍允許，App 讀到會換成對應的模板
-- 沛沛在 Supabase SQL Editor 執行一次即可（重跑不會出錯）

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_card_theme_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_card_theme_check CHECK (
  card_theme ~ '^[a-z_]{1,20}:[0-9]$'
  OR card_theme IN (
    'navy', 'forest', 'wine', 'graphite',
    'system_primary', 'dark_gold', 'cyan_slate', 'emerald', 'custom_color'
  )
);
ALTER TABLE public.profiles ALTER COLUMN card_theme SET DEFAULT 'classic:0';

COMMENT ON COLUMN public.profiles.card_theme IS '名片：模板代碼:配色編號（例 classic:0）；舊值 system_primary 等仍可讀';
