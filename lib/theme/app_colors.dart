import 'package:flutter/material.dart';

import 'app_accent.dart';

/// 全站共用的顏色 token。畫面要取顏色時用 `context.appColors.ink` 這種寫法，
/// 不要再寫死 `Colors.xxx` 或 `Color(0x...)`。
///
/// - bg：頁面底色（米白紙感）
/// - surface：卡片、對話框、輸入框底色
/// - surface2：次一層底色（表頭、選取列、灰底區塊）
/// - line：細線、邊框、分隔線
/// - ink / ink2 / ink3：主要文字 / 次要文字 / 說明與提示文字
/// - ok / okSoft：成功、正常（文字色 / 淡底色）
/// - warn / warnSoft：提醒、注意（文字色 / 淡底色）
/// - acc / accSoft：主題色 / 主題色淡底
/// - onAcc：放在主題色上面的文字顏色
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color acc;
  final Color accSoft;
  final Color onAcc;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.acc,
    required this.accSoft,
    required this.onAcc,
  });

  /// 明亮模式
  factory AppColors.light(AppAccent accent) {
    return AppColors(
      bg: const Color(0xFFF6F5F1),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFEFEDE7),
      line: const Color(0xFFE2DFD7),
      ink: const Color(0xFF161E29),
      ink2: const Color(0xFF47505D),
      ink3: const Color(0xFF666E7A),
      ok: const Color(0xFF2B6E4B),
      okSoft: const Color(0xFFE3EFE8),
      warn: const Color(0xFF94550C),
      warnSoft: const Color(0xFFF6EAD9),
      acc: accent.lightAccent,
      accSoft: accent.lightAccentSoft,
      onAcc: const Color(0xFFFFFFFF),
    );
  }

  /// 深色模式
  factory AppColors.dark(AppAccent accent) {
    return AppColors(
      bg: const Color(0xFF0E1319),
      surface: const Color(0xFF151C24),
      surface2: const Color(0xFF1C252F),
      line: const Color(0xFF29333F),
      ink: const Color(0xFFECEEF1),
      ink2: const Color(0xFFB2BAC4),
      ink3: const Color(0xFF8B95A1),
      ok: const Color(0xFF7CC49E),
      okSoft: const Color(0xFF17291F),
      warn: const Color(0xFFE2A65C),
      warnSoft: const Color(0xFF2E2318),
      acc: accent.darkAccent,
      accSoft: accent.darkAccentSoft,
      onAcc: const Color(0xFF0E1319),
    );
  }

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ok,
    Color? okSoft,
    Color? warn,
    Color? warnSoft,
    Color? acc,
    Color? accSoft,
    Color? onAcc,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ok: ok ?? this.ok,
      okSoft: okSoft ?? this.okSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      acc: acc ?? this.acc,
      accSoft: accSoft ?? this.accSoft,
      onAcc: onAcc ?? this.onAcc,
    );
  }

  /// 切換明亮／深色時，Flutter 會用這個做顏色漸變動畫
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      okSoft: Color.lerp(okSoft, other.okSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      acc: Color.lerp(acc, other.acc, t)!,
      accSoft: Color.lerp(accSoft, other.accSoft, t)!,
      onAcc: Color.lerp(onAcc, other.onAcc, t)!,
    );
  }
}
