import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../services/google_calendar_sync_service.dart';
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
        queryParams: {'prompt': 'select_account'},
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
      CustomToast.show(context, '已開啟：行程會放到 Google 日曆', ToastType.success);
    } else {
      CustomToast.show(context, '已關閉 Google 日曆同步', ToastType.warning);
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

    String calendarDescription = '開啟後，App 的行程會自動寫進你的 Google 日曆';
    Color calendarDescriptionColor = colors.ink3;
    if (isSyncEnabled) {
      calendarDescription = '已開啟：行程會自動寫進 Google 日曆（另開一本，不動到原本的行程）';
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
            ],
          ),
        ),
      ],
    );
  }
}
