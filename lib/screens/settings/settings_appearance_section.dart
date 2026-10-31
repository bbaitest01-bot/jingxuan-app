import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';
import 'accent_color_picker.dart';
import 'settings_parts.dart';

/// 系統設定第 1 區「外觀」：畫面亮暗、主題色
class SettingsAppearanceSection extends StatelessWidget {
  final AppSettings settings;

  const SettingsAppearanceSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(icon: Icons.palette_outlined, title: '外觀'),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('畫面亮暗', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.ink)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ThemeModeOption(
                      settings: settings,
                      mode: ThemeMode.light,
                      title: '淺色',
                      icon: Icons.light_mode_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeModeOption(
                      settings: settings,
                      mode: ThemeMode.dark,
                      title: '深色',
                      icon: Icons.dark_mode_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeModeOption(
                      settings: settings,
                      mode: ThemeMode.system,
                      title: '跟著電腦',
                      icon: Icons.brightness_auto_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 網頁版的「跟著電腦」是瀏覽器回報的明暗，不一定等於電腦的設定
              Text('選「跟著電腦」時，會依瀏覽器或手機的明暗自動切換', style: TextStyle(fontSize: 13, color: colors.ink3)),
              const SizedBox(height: 18),
              const SettingsDivider(),
              const SizedBox(height: 14),
              Text('主題色', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.ink)),
              const SizedBox(height: 12),
              AccentColorPicker(settings: settings),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// 亮暗的其中一個選項（選中的有主題色框）
class _ThemeModeOption extends StatelessWidget {
  final AppSettings settings;
  final ThemeMode mode;
  final String title;
  final IconData icon;

  const _ThemeModeOption({required this.settings, required this.mode, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool isSelected = settings.themeMode == mode;
    Color background = colors.surface2;
    Color borderColor = Colors.transparent;
    Color foreground = colors.ink2;
    if (isSelected) {
      background = colors.accSoft;
      borderColor = colors.acc;
      foreground = colors.acc;
    }
    return InkWell(
      onTap: () => settings.setThemeMode(mode),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
