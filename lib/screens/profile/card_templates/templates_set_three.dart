import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../profile_editor_state.dart';
import 'card_template.dart';

/// 名片模板第三組（2026-10-31 沛沛：模板再多一點）：雙色、角落、膠囊、點格、波浪、浮水印、側欄、霓光
/// 每個函式只排「正面」，背面由 `CardBackStyle` 決定

/// 雙色：上半主題色、下半底色，大頭貼跨在中間
Widget buildTwoToneFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 0, right: 0, top: 0, height: 92, child: ColoredBox(color: colors.accent)),
    Positioned(left: 24, right: 100, top: 26, child: CardName(name: data.name, size: 20, color: colors.onAccent)),
    Positioned(left: 24, right: 100, top: 56, child: CardSmallText(cardTitleLine(data), color: colors.onAccent.withValues(alpha: 0.8), size: 10)),
    Positioned(
      right: 24,
      top: 58,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: colors.base, shape: BoxShape.circle),
        child: CardAvatar(data: data, radius: 30, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap),
      ),
    ),
    Positioned(
      left: 24,
      right: 120,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.ink, weight: FontWeight.w600),
        CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2),
      ]),
    ),
  ]);
}

/// 角落：左上角一個主題色三角形
Widget buildCornerFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 0, top: 0, child: CustomPaint(size: const Size(96, 96), painter: _TrianglePainter(colors.accent))),
    Positioned(
      left: 0,
      right: 24,
      top: 52,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CardName(name: data.name, size: 21, color: colors.ink, align: TextAlign.right),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600, align: TextAlign.right),
      ]),
    ),
    Positioned(left: 24, bottom: 18, child: CardAvatar(data: data, radius: 22, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      right: 24,
      left: 90,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CardSmallText(data.company, color: colors.inkSoft, align: TextAlign.right),
        CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2, alignment: CrossAxisAlignment.end),
      ]),
    ),
  ]);
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
}

/// 膠囊：名字放在一個主題色膠囊裡
Widget buildPillFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 24, right: 24, top: 18, child: CardSmallText(data.company, color: colors.inkSoft, letterSpacing: 2)),
    Positioned(
      left: 20,
      top: 54,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 22, 6),
        decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CardAvatar(data: data, radius: 20, background: colors.onAccent.withValues(alpha: 0.2), foreground: colors.onAccent, onTap: onAvatarTap),
          const SizedBox(width: 10),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: CardName(name: data.name, size: 18, color: colors.onAccent)),
        ]),
      ),
    ),
    Positioned(left: 26, right: 24, top: 116, child: CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600)),
    Positioned(left: 26, right: 24, bottom: 14, child: CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft)),
  ]);
}

/// 點格：整張淡淡的點點方格，像筆記本
Widget buildDotGridFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned.fill(child: CustomPaint(painter: _DotGridPainter(colors.accent.withValues(alpha: 0.18)))),
    Positioned(
      left: 24,
      top: 24,
      child: Container(width: 30, height: 3, color: colors.accent),
    ),
    Positioned(
      left: 24,
      right: 90,
      top: 40,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 20, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
      ]),
    ),
    Positioned(right: 24, top: 30, child: CardAvatar(data: data, radius: 26, background: colors.base, foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      left: 24,
      right: 24,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.ink, weight: FontWeight.w600),
        CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ]),
    ),
  ]);
}

class _DotGridPainter extends CustomPainter {
  final Color color;

  _DotGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    for (double y = 12; y < size.height; y += 14) {
      for (double x = 12; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => oldDelegate.color != color;
}

/// 波浪：底部一條主題色波浪
Widget buildWaveFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 0, right: 0, bottom: 0, height: 64, child: CustomPaint(painter: _WavePainter(colors.accent))),
    Positioned(left: 24, top: 26, child: CardAvatar(data: data, radius: 26, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      left: 90,
      right: 24,
      top: 28,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 20, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
        CardSmallText(data.company, color: colors.inkSoft),
      ]),
    ),
    Positioned(left: 24, right: 24, bottom: 12, child: CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.onAccent)),
  ]);
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()..moveTo(0, size.height * 0.45);
    for (double x = 0; x <= size.width; x += 4) {
      final double y = size.height * 0.45 + math.sin(x / size.width * math.pi * 2) * 8;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.color != color;
}

/// 浮水印：名字第一個字大大的、淡淡地印在背景
Widget buildWatermarkFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  String initial = '';
  if (data.name.isNotEmpty) initial = data.name.substring(0, 1);
  return CardCanvas(background: colors.base, children: [
    Positioned(
      right: 6,
      top: -26,
      child: Text(initial, style: AppTextStyles.serif(fontSize: 190, color: colors.accent.withValues(alpha: 0.1))),
    ),
    Positioned(
      left: 24,
      right: 120,
      top: 62,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 22, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
      ]),
    ),
    Positioned(
      left: 24,
      right: 24,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.inkSoft, weight: FontWeight.w600),
        CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ]),
    ),
  ]);
}

/// 側欄：右邊一條窄窄的主題色側欄，公司名直排
Widget buildSidebarFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  final List<Widget> companyCharacters = [];
  for (final String character in data.company.characters.take(10)) {
    companyCharacters.add(Text(character, style: TextStyle(fontSize: 10, color: colors.onAccent, height: 1.3)));
  }
  return CardCanvas(background: colors.base, children: [
    Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 40,
      child: ColoredBox(color: colors.accent, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: companyCharacters))),
    ),
    Positioned(left: 24, top: 24, child: CardAvatar(data: data, radius: 24, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      left: 24,
      right: 60,
      top: 86,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 20, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
      ]),
    ),
    Positioned(left: 24, right: 60, bottom: 14, child: CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft)),
  ]);
}

/// 霓光：深色底、名字下面一條會發光的主題色細線
Widget buildNeonFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(
      left: 24,
      right: 24,
      top: 30,
      child: Row(children: [
        Expanded(child: CardSmallText(data.company, color: colors.inkSoft, letterSpacing: 2)),
        CardAvatar(data: data, radius: 18, background: colors.accent.withValues(alpha: 0.2), foreground: colors.accent, onTap: onAvatarTap),
      ]),
    ),
    Positioned(left: 24, right: 24, top: 80, child: CardName(name: data.name, size: 22, color: colors.ink)),
    Positioned(
      left: 24,
      top: 114,
      child: Container(
        width: 90,
        height: 2,
        decoration: BoxDecoration(
          color: colors.accent,
          boxShadow: [BoxShadow(color: colors.accent.withValues(alpha: 0.8), blurRadius: 8)],
        ),
      ),
    ),
    Positioned(left: 24, right: 24, top: 122, child: CardSmallText(cardTitleLine(data), color: colors.accent, size: 10)),
    Positioned(left: 24, right: 24, bottom: 14, child: CardSmallText(cardContactLines(data, maxItems: 2).join('  ・  '), color: colors.inkSoft)),
  ]);
}
