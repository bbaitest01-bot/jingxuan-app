import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../profile_editor_state.dart';
import 'card_template.dart';

/// 名片模板第一組（2026-10-31）：經典、夜幕、分割、直書、極簡、斜切
/// 每個函式只排「正面」，背面由 `CardBackStyle` 決定

/// 經典：米白紙、左邊細色條
Widget buildClassicFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: colors.accent)),
    Positioned(
      left: 26,
      right: 20,
      top: 16,
      child: Row(children: [
        Expanded(child: CardSmallText(data.company, color: colors.inkSoft, letterSpacing: 1)),
        if (data.licenseNo.isNotEmpty) CardSmallText('登錄字號 ${data.licenseNo}', color: colors.inkSoft, size: 8.5),
      ]),
    ),
    Positioned(
      left: 26,
      right: 20,
      top: 64,
      child: Row(children: [
        CardAvatar(data: data, radius: 24, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CardName(name: data.name, size: 20, color: colors.ink),
            CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
          ]),
        ),
      ]),
    ),
    Positioned(
      left: 26,
      right: 20,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.rule, width: 0.6))),
        child: CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ),
    ),
  ]);
}

/// 夜幕：深色底、主題色（金、銀、玫瑰金）細線
Widget buildNightFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 24, right: 24, top: 22, child: Container(height: 0.6, color: colors.accent)),
    Positioned(left: 24, right: 24, top: 30, child: CardSmallText(data.company, color: colors.accent, letterSpacing: 3)),
    Positioned(
      left: 24,
      right: 24,
      top: 76,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 21, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10),
      ]),
    ),
    Positioned(right: 24, top: 70, child: CardAvatar(data: data, radius: 22, background: colors.accent.withValues(alpha: 0.2), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(left: 24, right: 24, bottom: 14, child: CardSmallText(cardContactLines(data, maxItems: 2).join('  ・  '), color: colors.inkSoft)),
  ]);
}

/// 分割：左邊三分之一色塊放大頭貼
Widget buildSplitFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 128,
      child: ColoredBox(
        color: colors.accent,
        child: Center(
          child: CardAvatar(data: data, radius: 34, background: colors.onAccent.withValues(alpha: 0.2), foreground: colors.onAccent, onTap: onAvatarTap),
        ),
      ),
    ),
    Positioned(
      left: 150,
      right: 18,
      top: 36,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 18, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
        const SizedBox(height: 14),
        CardSmallText(data.company, color: colors.inkSoft),
        CardContactColumn(data: data, color: colors.inkSoft, maxItems: 3),
      ]),
    ),
  ]);
}

/// 直書：中文名字直式排、角落一顆印章（英文名字改橫式）
Widget buildVerticalFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  final bool isLatin = isLatinName(data.name);
  return CardCanvas(background: colors.base, children: [
    Positioned(
      right: 30,
      top: 18,
      bottom: 18,
      child: isLatin
          ? RotatedBox(quarterTurns: 1, child: CardName(name: data.name, size: 20, color: colors.ink))
          : _VerticalText(text: data.name.isEmpty ? '姓名' : data.name, size: 23, color: colors.ink, serif: true),
    ),
    Positioned(right: 68, top: 22, child: _VerticalText(text: cardTitleLine(data), size: 10, color: colors.accent)),
    Positioned(right: 26, bottom: 16, child: _Seal(colors: colors, name: data.name)),
    Positioned(
      left: 22,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.inkSoft, weight: FontWeight.w600),
        CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2),
      ]),
    ),
  ]);
}

/// 一個字一個字往下排（直書）
class _VerticalText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final bool serif;

  const _VerticalText({required this.text, required this.size, required this.color, this.serif = false});

  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(fontSize: size, color: color, height: 1.25);
    if (serif) style = AppTextStyles.serif(fontSize: size, color: color).copyWith(height: 1.3);
    final List<Widget> characters = [];
    for (final String character in text.characters.take(12)) {
      if (character == '・') {
        characters.add(SizedBox(height: size * 0.6));
        continue;
      }
      characters.add(Text(character, style: style));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: characters);
  }
}

/// 印章：主題色小方塊，裡面是名字第一個字
class _Seal extends StatelessWidget {
  final CardColorway colors;
  final String name;

  const _Seal({required this.colors, required this.name});

  @override
  Widget build(BuildContext context) {
    String character = '印';
    if (name.isNotEmpty && !isLatinName(name)) character = name.substring(0, 1);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(3)),
      child: Text(character, style: AppTextStyles.serif(fontSize: 13, color: colors.onAccent)),
    );
  }
}

/// 極簡：大量留白、一個小色點
Widget buildMinimalFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 26, top: 26, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle))),
    Positioned(
      left: 26,
      right: 150,
      bottom: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 17, color: colors.ink),
        CardSmallText([cardTitleLine(data), data.company].where((String part) => part.isNotEmpty).join(' ・ '), color: colors.inkSoft, size: 8.5),
      ]),
    ),
    Positioned(right: 24, bottom: 20, child: CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2, alignment: CrossAxisAlignment.end)),
  ]);
}

/// 斜切：右上一大塊斜切的主題色
Widget buildDiagonalFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(
      right: -60,
      top: -60,
      child: Transform.rotate(angle: 18 * math.pi / 180, child: Container(width: 200, height: 320, color: colors.accent)),
    ),
    Positioned(right: 22, top: 20, child: CardAvatar(data: data, radius: 26, background: colors.onAccent.withValues(alpha: 0.2), foreground: colors.onAccent, onTap: onAvatarTap)),
    Positioned(
      left: 24,
      right: 150,
      top: 58,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 20, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
      ]),
    ),
    Positioned(
      left: 24,
      right: 160,
      bottom: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.inkSoft, weight: FontWeight.w600),
        CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2),
      ]),
    ),
  ]);
}
