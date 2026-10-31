-- Migration: 20261101_schedule_reminder_settings.sql
-- 說明：增加每日行程提醒信之設定欄位與 pg_cron 每小時排程（段 2）
-- 規則：預設關閉（避免打擾）、預設時間 07:00（早上 7 點）

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS schedule_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS schedule_reminder_time TEXT NOT NULL DEFAULT '07:00';

COMMENT ON COLUMN public.profiles.schedule_reminder_enabled IS '每日行程提醒信：是否啟用（預設 false 關閉）';
COMMENT ON COLUMN public.profiles.schedule_reminder_time IS '每日行程提醒信：提醒時間（例 07:00、20:00）';

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 重跑時先移除舊的同名排程，避免重複
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
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
