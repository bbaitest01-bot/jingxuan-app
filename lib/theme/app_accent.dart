import 'package:flutter/material.dart';

/// 一種可選的主題色。明亮、深色模式各有一組「主色 acc」與「淡底 accSoft」，
/// 深色模式的主色比較亮，才看得清楚。
@immutable
class AppAccent {
  /// 給程式辨識用的代號，例如 'deep_sea'
  final String id;

  /// 顯示名稱的翻譯鍵（見 app_localizations.dart）
  final String nameKey;

  final Color lightAccent;
  final Color lightAccentSoft;
  final Color darkAccent;
  final Color darkAccentSoft;

  const AppAccent({
    required this.id,
    required this.nameKey,
    required this.lightAccent,
    required this.lightAccentSoft,
    required this.darkAccent,
    required this.darkAccentSoft,
  });

  /// 存進手機本機（prefs_primary_color）與帳號（primary_color_value）的數值：
  /// 一律存「明亮模式的主色」，讀回來時再用 [AppThemeColors.accentFromStoredValue] 找回整組顏色
  int get storedValue => lightAccent.toARGB32();

  /// 依目前是明亮還是深色，回傳該用的主色
  Color accentFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return darkAccent;
    }
    return lightAccent;
  }

  /// 依目前是明亮還是深色，回傳該用的淡底色
  Color accentSoftFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return darkAccentSoft;
    }
    return lightAccentSoft;
  }
}

/// 四種可選的主題色，以及舊版顏色的對應規則
class AppThemeColors {
  static const AppAccent deepSea = AppAccent(
    id: 'deep_sea',
    nameKey: 'accent_deep_sea',
    lightAccent: Color(0xFF1D4877),
    lightAccentSoft: Color(0xFFE6ECF4),
    darkAccent: Color(0xFF8DB3E0),
    darkAccentSoft: Color(0xFF1A2A3C),
  );

  static const AppAccent inkGreen = AppAccent(
    id: 'ink_green',
    nameKey: 'accent_ink_green',
    lightAccent: Color(0xFF225747),
    lightAccentSoft: Color(0xFFE3EDE9),
    darkAccent: Color(0xFF82C4AE),
    darkAccentSoft: Color(0xFF162C26),
  );

  static const AppAccent wine = AppAccent(
    id: 'wine',
    nameKey: 'accent_wine',
    lightAccent: Color(0xFF7A2B3A),
    lightAccentSoft: Color(0xFFF2E5E7),
    darkAccent: Color(0xFFE39AA6),
    darkAccentSoft: Color(0xFF351D23),
  );

  static const AppAccent graphite = AppAccent(
    id: 'graphite',
    nameKey: 'accent_graphite',
    lightAccent: Color(0xFF2C3644),
    lightAccentSoft: Color(0xFFE6E8EB),
    darkAccent: Color(0xFFBAC6D4),
    darkAccentSoft: Color(0xFF222B36),
  );

  /// 預設主題色
  static const AppAccent defaultAccent = deepSea;

  /// 設定頁色票依這個順序顯示
  static const List<AppAccent> palette = [deepSea, inkGreen, wine, graphite];

  /// 舊版（五種顏色）存過的數值 → 新的主題色
  static const Map<int, AppAccent> legacyColorMapping = {
    0xFF00ADB5: deepSea, // 舊「商務青藍」
    0xFF2563EB: deepSea, // 舊「皇家寶藍」
    0xFF10B981: inkGreen, // 舊「翡翠鮮綠」
    0xFF8B5CF6: wine, // 舊「高雅奢紫」
    0xFFF59E0B: graphite, // 舊「暖陽琥珀」
  };

  /// 把存起來的數值（可能是新值、舊值或看不懂的值）換成一種主題色。
  /// 看不懂的值一律用預設的深海藍，App 才不會因為舊資料壞掉
  static AppAccent accentFromStoredValue(int? storedValue) {
    if (storedValue == null) {
      return defaultAccent;
    }
    for (final AppAccent accent in palette) {
      if (accent.storedValue == storedValue) {
        return accent;
      }
    }
    final AppAccent? legacyAccent = legacyColorMapping[storedValue];
    if (legacyAccent != null) {
      return legacyAccent;
    }
    return defaultAccent;
  }
}
