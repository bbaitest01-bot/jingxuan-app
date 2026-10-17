import 'package:flutter/material.dart';

import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';

/// 設定頁的「主題色調」色票：深海藍、墨綠、酒紅、石墨，點一下就換
class AccentColorPicker extends StatelessWidget {
  final AppSettings settings;

  const AccentColorPicker({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppThemeColors.palette
          .map((AppAccent accent) => _AccentSwatch(
                accent: accent,
                isSelected: settings.accent.id == accent.id,
                onTap: () => settings.setAccent(accent),
              ))
          .toList(),
    );
  }
}

/// 一個色票：左邊圓點、右邊顏色名稱；選中時換成主題色淡底與主題色框
class _AccentSwatch extends StatelessWidget {
  final AppAccent accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 色票顯示目前明暗模式下實際會用的顏色
    final Brightness brightness = Theme.of(context).brightness;
    final Color color = accent.accentFor(brightness);
    final Color softColor = accent.accentSoftFor(brightness);
    final AppColors appColors = context.appColors;

    Color backgroundColor = appColors.surface2;
    Color borderColor = appColors.line;
    if (isSelected) {
      backgroundColor = softColor;
      borderColor = color;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n(accent.nameKey),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
                color: appColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
