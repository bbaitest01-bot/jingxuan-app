import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../models/schedule_event.dart';
import '../../services/calendar_sync_notice_service.dart';
import '../../services/google_calendar_sync_service.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/google_sign_in_button.dart';
import 'settings_parts.dart';

/// 系統設定第 4 區「Google 連線」：Google 帳號、行程放到 Google 日曆
/// （2026-11-01 從 settings_screen.dart 搬出；連線與同步的做法不變，只改版面與文字）
class SettingsGoogleSection extends StatefulWidget {
  const SettingsGoogleSection({super.key});

  @override
  State<SettingsGoogleSection> createState() => _SettingsGoogleSectionState();
}

class _SettingsGoogleSectionState extends State<SettingsGoogleSection> with WidgetsBindingObserver {
  bool _isResyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GoogleCalendarSyncService.instance.addListener(_onSyncServiceChanged);
    _loadSyncSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GoogleCalendarSyncService.instance.removeListener(_onSyncServiceChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 當使用者切回瀏覽器分頁或手機喚醒時，自動向雲端重新拉取最新的日曆同步開關狀態
    if (state == AppLifecycleState.resumed) {
      _loadSyncSettings();
    }
  }

  void _onSyncServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSyncSettings() async {
    await GoogleCalendarSyncService.instance.applyCloudSettings();
    if (mounted) setState(() {});
  }

  // 有沒有用 Google 登入或連結過 Google（離線預覽沒有 Supabase，直接當作沒連）
  bool _isGoogleConnected() {
    if (isOfflineMode) return false;
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;
    final List<UserIdentity> identities = currentUser.identities ?? [];
    for (final UserIdentity identity in identities) {
      if (identity.provider == 'google') return true;
    }
    if (currentUser.appMetadata['provider'] == 'google') return true;
    final Object? providers = currentUser.appMetadata['providers'];
    return providers is List && providers.contains('google');
  }

  Future<void> _connectGoogle() async {
    try {
      // 網頁版連完 Google 回到現在這個網址；本機開發固定回 8080
      String redirectTo = 'http://localhost:8080';
      if (kIsWeb) {
        final String origin = Uri.base.origin;
        final bool isOtherLocalPort = origin.contains('localhost') && !origin.contains(':8080');
        if (!isOtherLocalPort) redirectTo = origin;
      }
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        scopes: 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events',
        queryParams: {
          'prompt': 'consent select_account',
          'access_type': 'offline',
        },
      );
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '連線 Google 失敗：$error', ToastType.error);
    }
  }

  Future<void> _toggleCalendarSync(bool isEnabled) async {
    if (!isEnabled) {
      // 關閉同步：開關設為 false，並刪除 Google 日曆上的「經選助手」日曆（不同步就要都不見）
      try {
        await GoogleCalendarSyncService.instance.setSyncEnabled(false);
        await GoogleCalendarSyncService.instance.deleteSecondaryCalendar();
      } catch (e) {
        if (!mounted) return;
        CustomToast.show(context, '關閉同步失敗：$e', ToastType.error);
        setState(() {});
        return;
      }
      if (!mounted) return;
      setState(() {});
      CustomToast.show(context, '已關閉同步，並已從 Google 日曆移除「經選助手」行程', ToastType.warning);
    } else {
      // 開啟同步：開關設為 true，並自動將現有未刪除行程補推上去（同步才回來）
      try {
        await GoogleCalendarSyncService.instance.setSyncEnabled(true);
      } catch (e) {
        if (!mounted) return;
        CustomToast.show(context, '開啟同步失敗，無法更新帳號設定：$e', ToastType.error);
        setState(() {});
        return;
      }
      // 開始推送：不另外跳「正在同步」小提示（會和結果卡片疊在一起），改由「重新同步」按鈕顯示「同步中...」
      if (!mounted) return;
      setState(() => _isResyncing = true);
      await _pushAllEventsAndReport();
      if (mounted) setState(() => _isResyncing = false);
    }
  }

  Future<void> _resyncAllEvents() async {
    setState(() => _isResyncing = true);
    await _pushAllEventsAndReport();
    if (mounted) setState(() => _isResyncing = false);
  }

  /// G8：把所有行程推上 Google 日曆。
  /// 推送要等 Google 回應，等的時候使用者可能已經換頁，所以結果不在這裡跳提示，
  /// 而是收進鈴鐺（[_reportResult]），在任何頁面都看得到；成功、0 筆、出錯都會通知
  Future<void> _pushAllEventsAndReport() async {
    List<ScheduleEvent> events;
    try {
      events = await ScheduleService.instance.fetchEvents();
    } catch (error) {
      await _reportResult(0, '讀取行程失敗：$error');
      return;
    }
    if (events.isEmpty) {
      // 沒有行程：馬上就知道，不用等，直接在這頁提示
      if (!mounted) return;
      CustomToast.show(context, '目前沒有行程可同步，請先至「行程」新增一筆測試行程喔！', ToastType.warning);
      return;
    }

    int syncedCount = 0;
    String? errorMessage;
    try {
      syncedCount = await GoogleCalendarSyncService.instance.resyncAllEvents(events);
      if (syncedCount == 0) errorMessage = GoogleCalendarSyncService.instance.lastErrorMessage;
    } catch (error) {
      errorMessage = '$error';
    }
    await _reportResult(syncedCount, errorMessage);
  }

  // 結果收進鈴鐺；收不進去（例如資料庫還沒更新）而且還在設定頁時，改用小提示
  Future<void> _reportResult(int syncedCount, String? errorMessage) async {
    final bool isRecorded = await CalendarSyncNoticeService.instance.recordResult(
      syncedCount: syncedCount,
      errorMessage: errorMessage,
    );
    if (isRecorded || !mounted) return;
    if (syncedCount > 0) {
      CustomToast.show(context, '已同步 $syncedCount 筆行程至「經選助手」日曆', ToastType.success);
    } else {
      CustomToast.show(context, '同步未成功：${errorMessage ?? '沒有任何一筆行程同步成功'}', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool isConnected = _isGoogleConnected();
    final bool isSyncEnabled = GoogleCalendarSyncService.instance.isSyncEnabled;

    String accountDescription = '還沒連線';
    Color accountDescriptionColor = colors.ink3;
    if (isOfflineMode) {
      accountDescription = '離線預覽不能連線';
    } else if (isConnected) {
      accountDescription = '已連線（日曆權限就緒）';
      accountDescriptionColor = colors.ok;
    }
    Widget accountButton = FilledButton(onPressed: _connectGoogle, child: const Text('連線'));
    if (isConnected) accountButton = OutlinedButton(onPressed: _connectGoogle, child: const Text('切換帳號'));
    if (isOfflineMode) accountButton = const OutlinedButton(onPressed: null, child: Text('連線'));

    String calendarDescription = '開啟後，App 的行程會自動單向推送至 Google 日曆';
    Color calendarDescriptionColor = colors.ink3;
    if (isSyncEnabled) {
      calendarDescription = '已開啟：行程會自動寫進 Google 日曆「經選助手」（另開一本，App 為正本）';
      calendarDescriptionColor = colors.ok;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(icon: Icons.link_rounded, title: 'Google 連線'),
        SettingsCard(
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.account_circle_outlined,
                leadingIcon: const GoogleGLogoIcon(size: 20),
                title: 'Google 帳號',
                description: accountDescription,
                descriptionColor: accountDescriptionColor,
                trailing: accountButton,
              ),
              const SettingsDivider(),
              SettingsRow(
                icon: Icons.event_outlined,
                title: '行程放到 Google 日曆',
                description: calendarDescription,
                descriptionColor: calendarDescriptionColor,
                trailing: Switch(value: isSyncEnabled, onChanged: _toggleCalendarSync),
              ),
              if (isSyncEnabled) ...[
                const SettingsDivider(),
                SettingsRow(
                  icon: Icons.sync_rounded,
                  title: '重新同步所有行程',
                  description: '若在 Google 日曆誤刪，點此將未來的行程一鍵補回',
                  trailing: OutlinedButton(
                    onPressed: _isResyncing ? null : _resyncAllEvents,
                    child: Text(_isResyncing ? '同步中...' : '重新同步'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
