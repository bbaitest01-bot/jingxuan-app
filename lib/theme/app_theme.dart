import 'package:flutter/material.dart';

import 'app_accent.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

export 'app_accent.dart';
export 'app_colors.dart';
export 'app_text_styles.dart';

/// 圓角規則：按鈕、輸入框 8；卡片、對話框 12；Chip 999（膠囊形）
class AppRadius {
  static const double control = 8;
  static const double card = 12;
  static const double pill = 999;
}

/// 危險操作（刪除、清空）用的紅色。固定不跟主題色變，避免把「刪除」做成主題色
class AppDangerColors {
  static const Color lightDanger = Color(0xFFA8322D);
  static const Color lightDangerSoft = Color(0xFFF6E3E1);
  static const Color darkDanger = Color(0xFFE58A80);
  static const Color darkDangerSoft = Color(0xFF34201E);
}

/// 建立整個 App 的主題。明亮、深色共用同一套規則，只有顏色不同
class AppTheme {
  static ThemeData light(AppAccent accent) {
    return _build(Brightness.light, AppColors.light(accent), accent);
  }

  static ThemeData dark(AppAccent accent) {
    return _build(Brightness.dark, AppColors.dark(accent), accent);
  }

  static ThemeData _build(Brightness brightness, AppColors colors, AppAccent accent) {
    final bool isDark = brightness == Brightness.dark;
    final Color danger = isDark ? AppDangerColors.darkDanger : AppDangerColors.lightDanger;
    final Color dangerSoft = isDark ? AppDangerColors.darkDangerSoft : AppDangerColors.lightDangerSoft;
    final ColorScheme colorScheme = _buildColorScheme(brightness, colors, accent, danger, dangerSoft);
    final TextTheme textTheme = _buildTextTheme(brightness, colors);

    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: colors.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: colors.acc,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.surface,
      dividerColor: colors.line,
      textTheme: textTheme,
      // 全站內文用內建的思源黑體，網頁版第一個畫面就是正確的字
      fontFamily: AppTextStyles.bodyFamily,
      extensions: <ThemeExtension<dynamic>>[colors],

      // 主要按鈕：主題色底、onAcc 字
      filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle(colors, controlShape)),
      // 舊頁面大量使用 ElevatedButton，也當成主要按鈕
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle(colors, controlShape)),
      // 次要按鈕：白底、細框、深色字
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.line),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      // 文字按鈕：主題色字
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.acc,
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.acc,
        foregroundColor: colors.onAcc,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),

      inputDecorationTheme: _buildInputTheme(colors, danger),

      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
      ),
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.accSoft,
        checkmarkColor: colors.acc,
        labelStyle: TextStyle(color: colors.ink2, fontSize: 13),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        titleTextStyle: AppTextStyles.serif(fontSize: 18, color: colors.ink),
        contentTextStyle: TextStyle(fontSize: 14, height: 1.5, color: colors.ink2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.ink),
        titleTextStyle: AppTextStyles.serif(fontSize: 18, color: colors.ink),
        shape: Border(bottom: BorderSide(color: colors.line)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(color: colors.surface, fontSize: 14),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.acc,
        unselectedLabelColor: colors.ink2,
        indicatorColor: colors.acc,
        dividerColor: colors.line,
      ),
    );
  }

  static ColorScheme _buildColorScheme(
    Brightness brightness,
    AppColors colors,
    AppAccent accent,
    Color danger,
    Color dangerSoft,
  ) {
    final bool isDark = brightness == Brightness.dark;
    // 反色區塊（例如 SnackBar）上的主題色，要用另一個模式的主色才看得清楚
    final Color inverseAccent = isDark ? accent.lightAccent : accent.darkAccent;
    return ColorScheme(
      brightness: brightness,
      primary: colors.acc,
      onPrimary: colors.onAcc,
      primaryContainer: colors.accSoft,
      onPrimaryContainer: colors.acc,
      secondary: colors.acc,
      onSecondary: colors.onAcc,
      secondaryContainer: colors.accSoft,
      onSecondaryContainer: colors.acc,
      tertiary: colors.ok,
      onTertiary: colors.onAcc,
      tertiaryContainer: colors.okSoft,
      onTertiaryContainer: colors.ok,
      error: danger,
      onError: colors.onAcc,
      errorContainer: dangerSoft,
      onErrorContainer: danger,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.ink2,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface2,
      surfaceContainerHigh: colors.surface2,
      surfaceContainerHighest: colors.surface2,
      outline: colors.line,
      outlineVariant: colors.line,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
      inverseSurface: colors.ink,
      onInverseSurface: colors.surface,
      inversePrimary: inverseAccent,
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness, AppColors colors) {
    final TextTheme baseTextTheme = ThemeData(useMaterial3: true, brightness: brightness).textTheme;
    // 預設文字樣式帶有 Roboto 字型名稱，要明確換成內建黑體，否則會蓋掉 ThemeData 的 fontFamily
    final TextTheme coloredTextTheme = baseTextTheme.apply(
      fontFamily: AppTextStyles.bodyFamily,
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );
    return AppTextStyles.applySerifTitles(coloredTextTheme);
  }

  static ButtonStyle _primaryButtonStyle(AppColors colors, OutlinedBorder shape) {
    return FilledButton.styleFrom(
      backgroundColor: colors.acc,
      foregroundColor: colors.onAcc,
      disabledBackgroundColor: colors.surface2,
      disabledForegroundColor: colors.ink3,
      elevation: 0,
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static InputDecorationThemeData _buildInputTheme(AppColors colors, Color danger) {
    OutlineInputBorder borderWith(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationThemeData(
      filled: true,
      fillColor: colors.surface,
      labelStyle: TextStyle(color: colors.ink2),
      hintStyle: TextStyle(color: colors.ink3),
      prefixIconColor: colors.ink3,
      suffixIconColor: colors.ink3,
      border: borderWith(colors.line, 1),
      enabledBorder: borderWith(colors.line, 1),
      disabledBorder: borderWith(colors.line, 1),
      focusedBorder: borderWith(colors.acc, 1.5),
      errorBorder: borderWith(danger, 1),
      focusedErrorBorder: borderWith(danger, 1.5),
    );
  }
}

/// 可重用的特殊按鈕樣式
class AppButtonStyles {
  /// 危險按鈕（刪除、清空）：紅底白字，不使用主題色。
  /// 用法：`FilledButton(style: AppButtonStyles.danger(context), ...)`
  static ButtonStyle danger(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// 危險文字按鈕（對話框裡的「刪除」）：紅字、無底色
  static ButtonStyle dangerText(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
    );
  }
}

/// 在畫面裡取顏色 token：`context.appColors.ink`、`context.appColors.line`
extension AppThemeContext on BuildContext {
  AppColors get appColors {
    final ThemeData theme = Theme.of(this);
    final AppColors? colors = theme.extension<AppColors>();
    if (colors != null) {
      return colors;
    }
    // 測試或沒套用 App 主題的畫面：依明暗給預設深海藍的顏色，避免當掉
    if (theme.brightness == Brightness.dark) {
      return AppColors.dark(AppThemeColors.defaultAccent);
    }
    return AppColors.light(AppThemeColors.defaultAccent);
  }
}
