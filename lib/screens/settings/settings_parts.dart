import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 系統設定頁的共用小零件（2026-11-01 改版：拿掉 emoji 標題與重陰影，統一線條圖示）

/// 每一區上面的小標題：線條圖示＋名稱
class SettingsSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDanger;

  const SettingsSectionHeader({super.key, required this.icon, required this.title, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color iconColor = colors.acc;
    if (isDanger) iconColor = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.ink)),
        ],
      ),
    );
  }
}

/// 一區的白色卡片
class SettingsCard extends StatelessWidget {
  final Widget child;

  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      // 卡片裡的開關、按鈕要有自己的 Material，否則開發模式會跳出紅色錯誤畫面（2026-10-22）
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// 卡片裡的一列：左邊小圖示＋名稱＋一行說明，右邊放開關或按鈕；手機太窄時右邊換到下一行
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color? descriptionColor;
  final Widget? trailing;
  final Widget? leadingIcon;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.descriptionColor,
    this.trailing,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? descriptionText = description;
    final Widget? trailingWidget = trailing;
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.ink)),
        if (descriptionText != null) ...[
          const SizedBox(height: 2),
          Text(descriptionText, style: TextStyle(fontSize: 13, color: descriptionColor ?? colors.ink3)),
        ],
      ],
    );
    final Widget iconBox = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.accSoft, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: leadingIcon ?? Icon(icon, size: 19, color: colors.acc),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow = constraints.maxWidth < 460;
        if (trailingWidget != null && isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [iconBox, const SizedBox(width: 14), Expanded(child: textBlock)]),
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.only(left: 50), child: trailingWidget),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              iconBox,
              const SizedBox(width: 14),
              Expanded(child: textBlock),
              if (trailingWidget != null) ...[const SizedBox(width: 16), trailingWidget],
            ],
          ),
        );
      },
    );
  }
}

/// 卡片裡兩列之間的細線
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 12, color: context.appColors.line);
  }
}
