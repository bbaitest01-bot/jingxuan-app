import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import 'settings/settings_account_section.dart';
import 'settings/settings_appearance_section.dart';
import 'settings/settings_google_section.dart';
import 'settings/settings_reminder_section.dart';
import 'settings/settings_tutorial_section.dart';
import 'settings/settings_work_section.dart';

/// 系統設定頁（2026-11-01 改版：一條直排，順序 外觀 → 使用習慣 → 教學中心 → Google 連線 → 帳號）
///
/// 常用的放上面、設一次就好的往後放、危險的放最後；每一區拆成 settings/ 裡的小檔案。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (BuildContext context, Widget? child) {
        final AppSettings settings = AppSettings.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SettingsHeader(),
                  const SizedBox(height: 24),
                  SettingsAppearanceSection(settings: settings),
                  const SizedBox(height: 28),
                  SettingsWorkSection(settings: settings),
                  const SizedBox(height: 28),
                  const SettingsTutorialSection(),
                  const SizedBox(height: 28),
                  const SettingsGoogleSection(),
                  const SizedBox(height: 28),
                  const SettingsReminderSection(),
                  const SizedBox(height: 28),
                  SettingsAccountSection(settings: settings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 頁首：一句白話說明設定存在哪裡（2026-11-01 拿掉 Supabase／SharedPreferences 等技術字）
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String description = '改了就自動存到你的帳號，換電腦登入也一樣';
    String statusText = '已同步';
    IconData statusIcon = Icons.cloud_done_outlined;
    Color statusColor = colors.ok;
    if (isOfflineMode) {
      description = '離線預覽中，設定只存在這台電腦';
      statusText = '只存本機';
      statusIcon = Icons.cloud_off_outlined;
      statusColor = colors.warn;
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(description, style: TextStyle(fontSize: 14, color: colors.ink2)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 4),
            Text(statusText, style: TextStyle(fontSize: 13, color: statusColor)),
          ],
        ),
      ],
    );
  }
}
