import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 字體規則：
/// - 標題（display、headline、title 系列）：Noto Serif TC（宋體）
/// - 數字、時間：IBM Plex Mono，用 [AppTextStyles.mono]
/// - 內文：不指定字型，交給系統中文字（蘋方、微軟正黑體）
class AppTextStyles {
  /// 標題只用一種粗細：宋體每種粗細都是約 10MB 的字型檔，
  /// 網頁版每多一種粗細就要多下載一次
  static const FontWeight titleWeight = FontWeight.w600;

  /// 內文找不到預設字型時，依序改用這些系統中文字
  static const List<String> systemChineseFallback = [
    'PingFang TC',
    'Heiti TC',
    'Microsoft JhengHei',
    'Noto Sans TC',
  ];

  /// 把標題系列換成宋體，內文（body、label）維持原樣
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
    return GoogleFonts.notoSerifTc(
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
    return GoogleFonts.ibmPlexMono(
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
    return GoogleFonts.notoSerifTc(textStyle: style, fontWeight: titleWeight);
  }
}
