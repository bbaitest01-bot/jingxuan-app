import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';

/// 登入頁右上角的明亮／深色切換。
/// 還沒登入時只存在這台裝置；登入後會改用帳號裡存的設定。
class LoginThemeToggle extends StatelessWidget {
  const LoginThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // 依「現在畫面」是明是暗決定要切到哪一邊（跟隨系統時也一樣）
    final bool isDarkNow = Theme.of(context).brightness == Brightness.dark;

    IconData icon = Icons.dark_mode_outlined;
    String tooltip = '切換為深色';
    ThemeMode nextMode = ThemeMode.dark;
    if (isDarkNow) {
      icon = Icons.light_mode_outlined;
      tooltip = '切換為明亮';
      nextMode = ThemeMode.light;
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: () => AppSettings.instance.setThemeMode(nextMode),
      icon: Icon(icon, size: 20, color: colors.ink2),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }
}
