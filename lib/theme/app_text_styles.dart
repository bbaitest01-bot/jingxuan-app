import 'package:flutter/material.dart';

/// 字體規則：
/// - 內文：思源黑體 Noto Sans TC（[bodyFamily]）
/// - 標題（display、headline、title 系列）：思源宋體 Noto Serif TC（[titleFamily]）
/// - 數字、時間：IBM Plex Mono，用 [AppTextStyles.mono]
///
/// 三種字型都內建在 assets/fonts/（pubspec.yaml 的 fonts 區塊），不從網路下載。
/// Flutter 網頁版是自己畫字、用不到瀏覽器的系統字，沒有內建字型時中文會先顯示方框（問題總表 X16）。
/// 內建字型只收常用字，罕見字會改用 Flutter 臨時下載的備用字；要補字請重跑 tool/build_font_subset.py。
class AppTextStyles {
  /// 字型名稱，要和 pubspec.yaml 的 family 一模一樣
  static const String bodyFamily = 'NotoSansTC';
  static const String titleFamily = 'NotoSerifTC';
  static const String monoFamily = 'IBMPlexMono';

  /// 標題只內建一種粗細（宋體每種粗細約 2.8MB）
  static const FontWeight titleWeight = FontWeight.w600;

  /// 宋體、等寬字裡沒有的字，改用內建的黑體顯示
  static const List<String> chineseFallback = [bodyFamily];

  /// 把標題系列換成宋體，內文（body、label）維持黑體
  static TextTheme applySerifTitles(TextTheme base) {
    return base.copyWith(
      displayLarge: _serif(base.displayLarge),
      displayMedium: _serif(base.displayMedium),
      displaySmall: _serif(base.displaySmall),
      headlineLarge: _serif(base.headlineLarge),
      headlineMedium: _serif(base.headlineMedium),
      headlineSmall: _serif(base.headlineSmall),
      titleLarge: _serif(base.titleLarge),
      titleMedium: _serif(base.titleMedium),
      titleSmall: _serif(base.titleSmall),
    );
  }

  /// 宋體標題樣式。需要自己組標題時可直接用，例如 `AppTextStyles.serif(fontSize: 20)`
  static TextStyle serif({double? fontSize, Color? color}) {
    return TextStyle(
      fontFamily: titleFamily,
      fontFamilyFallback: chineseFallback,
      fontSize: fontSize,
      color: color,
      fontWeight: titleWeight,
    );
  }

  /// 數字、金額、時間用的等寬字。數字寬度固定，上下排列時會對齊
  static TextStyle mono({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: chineseFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle? _serif(TextStyle? style) {
    if (style == null) {
      return null;
    }
    return style.copyWith(
      fontFamily: titleFamily,
      fontFamilyFallback: chineseFallback,
      fontWeight: titleWeight,
    );
  }
}
