import 'package:flutter/material.dart';

/// 一種「分類色」：實心色與淡底色，明亮、深色各一套。
/// 實心色上的字用 `context.appColors.onAcc`（明亮白字、深色深字）。
class AppCategoryColor {
  final Color light;
  final Color lightSoft;
  final Color dark;
  final Color darkSoft;

  const AppCategoryColor({
    required this.light,
    required this.lightSoft,
    required this.dark,
    required this.darkSoft,
  });

  /// 實心色（色條、圓點、標籤底）
  Color solid(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return dark;
    }
    return light;
  }

  /// 淡底色（卡片底、淡標籤底）
  Color soft(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return darkSoft;
    }
    return lightSoft;
  }
}

/// 全站共用的四種分類色（「清爽組」，2026-10-18 沛沛選定）。
/// 固定顏色、不跟主題色變，彼此分得開；行程類型、客戶關係類型等「分類」都用這一組。
class AppCategoryColors {
  static const AppCategoryColor blue = AppCategoryColor(
    light: Color(0xFF2F6DB5),
    lightSoft: Color(0xFFE4EDF8),
    dark: Color(0xFF7FB0E8),
    darkSoft: Color(0xFF1A2A3D),
  );
  static const AppCategoryColor teal = AppCategoryColor(
    light: Color(0xFF1A7A6C),
    lightSoft: Color(0xFFE0F0EC),
    dark: Color(0xFF6CC3B3),
    darkSoft: Color(0xFF142D29),
  );
  static const AppCategoryColor orange = AppCategoryColor(
    light: Color(0xFFA85A12),
    lightSoft: Color(0xFFF6E8D8),
    dark: Color(0xFFE8A35E),
    darkSoft: Color(0xFF33251A),
  );
  static const AppCategoryColor gray = AppCategoryColor(
    light: Color(0xFF6B717C),
    lightSoft: Color(0xFFECEDEF),
    dark: Color(0xFFA0A6AF),
    darkSoft: Color(0xFF23272D),
  );
}
