-- 2026-10-31 經選日報第二步：AI 短重點、關鍵數字、AI 插圖
-- 沛沛在 Supabase SQL Editor 執行一次即可（重跑不會出錯）

-- 1. 話題多三個欄位（由每天抓新聞的雲端函式寫入，App 只讀）
ALTER TABLE public.insurance_news_topics
  ADD COLUMN IF NOT EXISTS short_summary TEXT,      -- 一句 35 字以內的重點
  ADD COLUMN IF NOT EXISTS key_number TEXT,         -- 關鍵數字，例「8,100 萬」
  ADD COLUMN IF NOT EXISTS key_number_label TEXT;   -- 這個數字代表什麼，例「農業保險理賠」
-- 原本的 RLS 不變：登入的人可以讀，寫入只有雲端函式（service role）

-- 2. 放 AI 插圖的公開空間：任何人可以看圖（圖不含個資），
--    但沒有開放任何上傳／刪除權限，只有雲端函式用 service role 能放圖
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('news-images', 'news-images', true, 3145728, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;
