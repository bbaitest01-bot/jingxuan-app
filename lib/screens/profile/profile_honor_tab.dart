import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import 'profile_editor_state.dart';
import 'profile_form_parts.dart';

/// 分頁「榮譽與徽章」：名片頭銜、證照徽章、服務理念、LINE QR Code
class ProfileHonorTab extends StatefulWidget {
  final ProfileEditorState editor;
  final VoidCallback onPickQrCode;

  const ProfileHonorTab({super.key, required this.editor, required this.onPickQrCode});

  @override
  State<ProfileHonorTab> createState() => _ProfileHonorTabState();
}

class _ProfileHonorTabState extends State<ProfileHonorTab> {
  final TextEditingController _customHonorController = TextEditingController();
  final TextEditingController _customBadgeController = TextEditingController();

  @override
  void dispose() {
    _customHonorController.dispose();
    _customBadgeController.dispose();
    super.dispose();
  }

  void _addHonor() {
    final String title = _customHonorController.text.trim();
    if (title.isEmpty) return;
    widget.editor.addCustomHonorTitle(title);
    _customHonorController.clear();
    CustomToast.show(context, '已新增頭銜：$title', ToastType.success);
  }

  void _addBadge() {
    final String badge = _customBadgeController.text.trim();
    if (badge.isEmpty) return;
    widget.editor.addCustomBadge(badge);
    _customBadgeController.clear();
    CustomToast.show(context, '已新增並選取：$badge', ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final ProfileEditorState editor = widget.editor;
    final AppColors colors = context.appColors;
    final List<Widget> honorChips = [
      _OptionChip(label: '不放頭銜', isSelected: editor.honorTitle.isEmpty, onTap: () => editor.selectHonorTitle('')),
    ];
    for (final String title in editor.availableHonorTitles) {
      honorChips.add(_OptionChip(
        label: title,
        isSelected: editor.honorTitle == title,
        onTap: () => editor.selectHonorTitle(title),
      ));
    }
    final List<Widget> badgeChips = [];
    for (final String badge in editor.availableBadges) {
      badgeChips.add(_OptionChip(
        label: badge,
        isSelected: editor.selectedBadges.contains(badge),
        isCheck: true,
        onTap: () => editor.toggleBadge(badge),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle(title: '名片頭銜', description: '印在名字下面、職稱後面；選一個或自己打'),
        Wrap(spacing: 8, runSpacing: 8, children: honorChips),
        const SizedBox(height: 10),
        _AddRow(controller: _customHonorController, hint: '自訂頭銜，例：退休規劃顧問', onAdd: _addHonor),
        const SizedBox(height: 26),
        ProfileSectionTitle(
          title: '證照徽章',
          description: '印在名片背面，最多顯示 4 個（已選 ${editor.selectedBadges.length} 個）',
        ),
        Wrap(spacing: 8, runSpacing: 8, children: badgeChips),
        const SizedBox(height: 10),
        _AddRow(controller: _customBadgeController, hint: '自訂證照，例：CFP 國際理財規劃師', onAdd: _addBadge),
        const SizedBox(height: 26),
        const ProfileSectionTitle(title: '名片背面'),
        ProfileField(label: '服務理念（印在背面）', controller: editor.bioController, maxLines: 3),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                editor.qrCodeProvider == null ? 'LINE QR Code：還沒上傳（上傳後印在背面右邊）' : 'LINE QR Code：已上傳',
                style: TextStyle(fontSize: 14, color: colors.ink2),
              ),
            ),
            OutlinedButton(
              onPressed: widget.onPickQrCode,
              child: Text(editor.qrCodeProvider == null ? '上傳' : '更換'),
            ),
            if (editor.qrCodeProvider != null)
              TextButton(
                // 移除後按「儲存變更」才會從名片上拿掉
                onPressed: () {
                  editor.newQrCodeBytes = null;
                  editor.qrCodeUrl = '';
                  editor.changed();
                },
                child: Text('移除', style: TextStyle(color: colors.ink3)),
              ),
          ],
        ),
      ],
    );
  }
}

/// 可以選的小膠囊：選中填主題色（頭銜）或打勾（徽章）
class _OptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCheck;
  final VoidCallback onTap;

  const _OptionChip({required this.label, required this.isSelected, required this.onTap, this.isCheck = false});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color background = Colors.transparent;
    Color foreground = colors.ink2;
    Color border = colors.line;
    if (isSelected && isCheck) {
      background = colors.accSoft;
      foreground = colors.acc;
      border = colors.acc.withValues(alpha: 0.4);
    } else if (isSelected) {
      background = colors.acc;
      foreground = colors.onAcc;
      border = colors.acc;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCheck && isSelected) ...[Icon(Icons.check_rounded, size: 14, color: foreground), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 13, color: foreground)),
          ],
        ),
      ),
    );
  }
}

/// 自訂輸入＋「新增」按鈕
class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  const _AddRow({required this.controller, required this.hint, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: ProfileField(label: '自訂', controller: controller, hintText: hint)),
        const SizedBox(width: 10),
        OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 16), label: const Text('新增')),
      ],
    );
  }
}
