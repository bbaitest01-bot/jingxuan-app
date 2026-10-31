import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import 'delete_account_dialog.dart';
import 'settings_parts.dart';

/// 系統設定最後一區「帳號」：語言（只有切成英文的人才看得到）、設定改回預設、刪除帳號
///
/// 2026-11-01 沛沛：語言選項先藏起來，因為很多頁還沒翻譯，切成英文會中英混雜；
/// 已經切成英文的人還是看得到，才切得回中文。
class SettingsAccountSection extends StatelessWidget {
  final AppSettings settings;

  const SettingsAccountSection({super.key, required this.settings});

  Future<void> _confirmReset(BuildContext context) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('設定改回預設'),
        content: const Text('畫面亮暗、主題色、客戶排法、左邊選單都會改回一開始的樣子。客戶與行程資料不受影響。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('改回預設')),
        ],
      ),
    );
    if (isConfirmed != true) return;
    await settings.resetToDefaults();
    if (!context.mounted) return;
    CustomToast.show(context, '設定已改回預設', ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnglish = settings.language != 'zh_TW';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(icon: Icons.manage_accounts_outlined, title: '帳號'),
        SettingsCard(
          child: Column(
            children: [
              if (isEnglish) ...[
                SettingsRow(
                  icon: Icons.translate_rounded,
                  title: '語言 Language',
                  description: '英文版還沒做完，建議用中文',
                  trailing: OutlinedButton(
                    onPressed: () => settings.setLanguage('zh_TW'),
                    child: const Text('改回中文'),
                  ),
                ),
                const SettingsDivider(),
              ],
              SettingsRow(
                icon: Icons.restart_alt_rounded,
                title: '設定改回預設',
                description: '只改這頁的設定，資料不受影響',
                trailing: OutlinedButton(onPressed: () => _confirmReset(context), child: const Text('改回預設')),
              ),
              const SettingsDivider(),
              SettingsRow(
                icon: Icons.person_remove_outlined,
                title: '刪除帳號',
                description: '帳號與所有資料（客戶、保單、行程、拜訪紀錄、照片）會永久刪除，無法復原',
                trailing: OutlinedButton(
                  style: AppButtonStyles.danger(context),
                  onPressed: () => DeleteAccountDialog.show(context),
                  child: const Text('刪除帳號'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
