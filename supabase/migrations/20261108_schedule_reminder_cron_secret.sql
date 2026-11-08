-- ============================================================================
-- M7：提醒信排程呼叫雲端函式時，帶上安全密碼
-- 日期：2026-11-08
--
-- 原本（20261101_schedule_reminder_settings.sql）排程呼叫 send-daily-schedule-reminder 沒帶密碼，
-- 函式也只有「有設定密碼才檢查」，所以知道網址的人可以重複觸發，讓業務員收到重複的提醒信。
-- 這次改成：
--   1. 密碼存在 Supabase Vault（名稱 reminder_cron_secret），不寫進 repo
--   2. 排程每次從 Vault 讀出密碼，放在 x-reminder-cron-secret 送給函式
--   3. 函式一律檢查（沒設定或不對就拒絕）
--
-- ⚠️ 執行這段之前，要先在 SQL Editor 執行一次（把密碼換成你自己產生的那一串，不要提交到 repo）：
--   SELECT vault.create_secret('<和雲端函式 REMINDER_CRON_SECRET 同一串>', 'reminder_cron_secret');
-- 可重複執行：先移除舊的同名排程再建立。
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. 沒有先存密碼就停下來，避免排程每小時都被函式拒絕卻沒人發現
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'reminder_cron_secret') THEN
    RAISE EXCEPTION 'Vault 裡沒有 reminder_cron_secret，請先執行 vault.create_secret（見本檔開頭說明）';
  END IF;
END $$;

-- 2. 重建排程：每小時整點呼叫，標頭帶上從 Vault 讀出的密碼
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-schedule-reminder-hourly') THEN
    PERFORM cron.unschedule('daily-schedule-reminder-hourly');
  END IF;
END $$;

SELECT cron.schedule(
  'daily-schedule-reminder-hourly',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/send-daily-schedule-reminder',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-reminder-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'reminder_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
