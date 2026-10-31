-- 2026-10-31 每日新聞改由 Supabase 自己準時排程（原本 GitHub Actions 的定時常延後好幾小時）
-- 每天台灣時間 06:00、18:00（UTC 22:00、10:00）呼叫雲端函式 fetch-insurance-news
--
-- 執行前要先：
--   1. 開啟 pg_cron、pg_net
--   2. 在 Vault 存好排程密碼，名稱 news_cron_secret（值要和函式 Secret NEWS_CRON_SECRET 一樣）
-- 密碼不寫在這個檔案裡，執行時才從 Vault 讀出來

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 重跑時先移除舊的同名排程，避免重複
SELECT cron.unschedule(jobname)
FROM cron.job
WHERE jobname = 'daily-insurance-news';

SELECT cron.schedule(
  'daily-insurance-news',
  '0 10,22 * * *',
  $$
  SELECT net.http_post(
    url := 'https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/fetch-insurance-news',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-news-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'news_cron_secret')
    ),
    body := '{}'::jsonb,
    -- 抓新聞＋畫圖要一兩分鐘，等久一點
    timeout_milliseconds := 150000
  );
  $$
);
