-- ============================================================================
-- G8：Google 日曆同步的結果收進鈴鐺（通知中心）
-- 日期：2026-11-08
--
-- 問題：同步要等 Google 回應，等的時候換頁，設定頁就收不到結果，提示不會跳。
-- 沛沛決定：成功、失敗都像「拜訪紀錄整理完成」一樣跳通知卡片、收進鈴鐺（事後也查得到）。
--
-- 做法（沿用 20261017_notifications.sql 的安全原則）：
--   1. 通知類型多兩種：calendar_sync_done（成功）、calendar_sync_failed（失敗）
--   2. App 仍然「不能直接新增通知」；改呼叫函式 record_calendar_sync_result()，
--      函式以登入者本人身分新增一則，標題與內容由資料庫決定（App 只給筆數與錯誤原因）
--   3. 防洗版：同一個人 1 分鐘內最多 5 則日曆同步通知，超過就不再新增
-- 可重複執行：約束先 DROP IF EXISTS；函式用 CREATE OR REPLACE。
-- ============================================================================

-- 1. 通知類型加兩種
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (type IN (
    'visit_record_ready', 'visit_record_failed', 'schedule_reminder',
    'calendar_sync_done', 'calendar_sync_failed'
  ));

-- 2. 記錄一次同步結果（成功 N 筆，或失敗原因）
CREATE OR REPLACE FUNCTION public.record_calendar_sync_result(
  p_synced_count INTEGER,
  p_error_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id UUID := auth.uid();
  v_recent_count INTEGER;
BEGIN
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '請先登入';
  END IF;
  IF p_synced_count IS NULL OR p_synced_count < 0 OR p_synced_count > 10000 THEN
    RAISE EXCEPTION '同步筆數不正確';
  END IF;

  -- 防洗版：1 分鐘內已經有 5 則就不再新增
  SELECT count(*) INTO v_recent_count
  FROM public.notifications
  WHERE profile_id = v_profile_id
    AND type IN ('calendar_sync_done', 'calendar_sync_failed')
    AND created_at > now() - INTERVAL '1 minute';
  IF v_recent_count >= 5 THEN
    RETURN;
  END IF;

  IF p_synced_count > 0 THEN
    INSERT INTO public.notifications (profile_id, type, title, content)
    VALUES (
      v_profile_id,
      'calendar_sync_done',
      '行程已同步到 Google 日曆',
      '已把 ' || p_synced_count || ' 筆行程放到 Google 日曆的「經選助手」日曆'
    );
  ELSE
    INSERT INTO public.notifications (profile_id, type, title, content)
    VALUES (
      v_profile_id,
      'calendar_sync_failed',
      '行程同步到 Google 日曆失敗',
      left(
        '原因：' || coalesce(nullif(trim(p_error_message), ''), '沒有任何一筆行程同步成功')
          || '。可以到「系統設定」按「重新同步」再試一次',
        500
      )
    );
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_calendar_sync_result(INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_calendar_sync_result(INTEGER, TEXT) TO authenticated;
