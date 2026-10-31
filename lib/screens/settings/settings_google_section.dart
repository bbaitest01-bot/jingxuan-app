import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
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

class _SettingsGoogleSectionState extends State<SettingsGoogleSection> {
  bool _isResyncing = false;

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
        scopes: 'https://www.googleapis.com/auth/calendar',
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
    await GoogleCalendarSyncService.instance.setSyncEnabled(isEnabled);
    if (!mounted) return;
    setState(() {});
    if (isEnabled) {
      CustomToast.show(context, '已開啟：行程會單向推送至 Google 日曆', ToastType.success);
    } else {
      CustomToast.show(context, '已關閉 Google 日曆同步', ToastType.warning);
    }
  }

  Future<void> _resyncAllEvents() async {
    setState(() => _isResyncing = true);
    try {
      final events = await ScheduleService.instance.fetchEvents();
      if (events.isEmpty) {
        if (!mounted) return;
        CustomToast.show(context, '目前沒有行程可同步，請先至「行程」新增一筆測試行程喔！', ToastType.warning);
        return;
      }

      final count = await GoogleCalendarSyncService.instance.resyncAllEvents(events);
      if (!mounted) return;

      if (count > 0) {
        CustomToast.show(
          context,
          '重新同步完成！成功推送 $count 筆行程至「經選助手」日曆',
          ToastType.success,
        );
      } else {
        final String? error = GoogleCalendarSyncService.instance.lastErrorMessage;
        CustomToast.show(
          context,
          error != null ? '同步未成功：$error' : '未成功同步任何行程',
          ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '重新同步失敗：$e', ToastType.error);
    } finally {
      if (mounted) setState(() => _isResyncing = false);
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
      accountDescription = '已連線';
      accountDescriptionColor = colors.ok;
    }
    Widget accountButton = FilledButton(onPressed: _connectGoogle, child: const Text('連線'));
    if (isConnected) accountButton = OutlinedButton(onPressed: _connectGoogle, child: const Text('重新授權'));
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
