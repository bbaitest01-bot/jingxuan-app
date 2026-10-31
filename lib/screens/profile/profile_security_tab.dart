import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../services/profile_editor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/reset_password_dialog.dart';
import 'profile_editor_state.dart';
import 'profile_form_parts.dart';

/// 分頁「帳號安全」：帳號身分、改密碼、刪除帳號（功能不變，2026-10-31 只換外觀與白話文字）
class ProfileSecurityTab extends StatelessWidget {
  final ProfileEditorState editor;

  /// 開發者「回到開發者控制台」
  final ValueChanged<UserRole>? onRoleChanged;

  const ProfileSecurityTab({super.key, required this.editor, this.onRoleChanged});

  String get _roleDescription {
    if (editor.role.isAdmin) return '可以管理全系統的設定與角色';
    if (editor.role.isDev) return '開發者，可以使用測試工具與除錯面板';
    return '業務員，管理自己的客戶與行程';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool canToggleStatus = editor.role == UserRole.dev || editor.role == UserRole.admin;
    final ValueChanged<UserRole>? roleChanged = onRoleChanged;
    final Color errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle(title: '帳號安全'),
        _SecurityRow(
          icon: editor.role.badgeIcon,
          title: '帳號身分：${editor.role.shortLabel}',
          description: _roleDescription,
          action: canToggleStatus
              ? TextButton(onPressed: () => _toggleStatus(context), child: const Text('切換帳號狀態（測試）'))
              : null,
        ),
        if (editor.role == UserRole.dev && roleChanged != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => roleChanged(UserRole.dev),
              icon: const Icon(Icons.developer_board_rounded, size: 16),
              label: const Text('回到開發者控制台'),
            ),
          ),
        Divider(height: 28, color: colors.line),
        _SecurityRow(
          icon: Icons.lock_outline_rounded,
          title: '密碼',
          description: '設定新的登入密碼',
          action: OutlinedButton(
            onPressed: () => showDialog(context: context, builder: (BuildContext dialogContext) => const ResetPasswordDialog()),
            child: const Text('重設密碼'),
          ),
        ),
        Divider(height: 28, color: colors.line),
        _SecurityRow(
          icon: Icons.delete_outline_rounded,
          iconColor: errorColor,
          title: '刪除帳號',
          description: '會永久刪除所有資料，到「系統設定」最下方操作',
          action: TextButton(
            onPressed: () => _showDeleteAccountInfo(context),
            child: Text('怎麼刪除', style: TextStyle(color: errorColor)),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleStatus(BuildContext context) async {
    try {
      final String newStatus = await ProfileEditorService.toggleAccountStatus(editor);
      if (!context.mounted) return;
      String label = '待主管審核';
      if (newStatus == 'active') label = '帳號正常';
      CustomToast.show(context, '測試：帳號狀態已切換為「$label」', ToastType.success);
    } catch (error) {
      if (!context.mounted) return;
      CustomToast.show(context, '狀態切換失敗：$error', ToastType.error);
    }
  }

  void _showDeleteAccountInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('刪除帳號'),
        content: const Text(
          '請到左側選單「系統設定」，在最下方「刪除帳號」操作。\n\n刪除前會列出會被刪掉的資料，並需要輸入「刪除帳號」四個字確認。',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('了解'))],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String description;
  final Widget? action;

  const _SecurityRow({required this.icon, required this.title, required this.description, this.action, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget? trailing = action;
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor ?? colors.acc),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 13, color: colors.ink3)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
