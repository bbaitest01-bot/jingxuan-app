import 'package:flutter/material.dart';

import '../profile_editor_state.dart';
import 'card_template.dart';

/// 名片模板第二組（2026-10-31）：金框、報紙、水墨、條紋、圓弧、名牌
/// 每個函式只排「正面」，背面由 `CardBackStyle` 決定

/// 金框：雙線框、置中排版，像邀請函
Widget buildFrameFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned.fill(child: Padding(padding: const EdgeInsets.all(10), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: colors.accent, width: 1))))),
    Positioned.fill(child: Padding(padding: const EdgeInsets.all(14), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: colors.accent, width: 0.5))))),
    Positioned(
      left: 30,
      right: 30,
      top: 34,
      child: Column(children: [
        CardSmallText(data.company, color: colors.accent, letterSpacing: 3, align: TextAlign.center),
        const SizedBox(height: 14),
        CardName(name: data.name, size: 20, color: colors.ink, align: TextAlign.center),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, align: TextAlign.center),
      ]),
    ),
    Positioned(
      left: 30,
      right: 30,
      bottom: 26,
      child: CardSmallText(cardContactLines(data, maxItems: 2).join('  ・  '), color: colors.inkSoft, align: TextAlign.center),
    ),
  ]);
}

/// 報紙：跟新聞頁「經選日報」同一套——雙線、紅色小標、宋體大名字
Widget buildNewspaperFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  final String title = cardTitleLine(data);
  return CardCanvas(background: colors.base, children: [
    Positioned(
      left: 18,
      right: 18,
      top: 16,
      child: Column(children: [
        Container(height: 2, color: colors.ink),
        const SizedBox(height: 2),
        Container(height: 0.6, color: colors.ink),
      ]),
    ),
    if (title.isNotEmpty)
      Positioned(
        left: 18,
        top: 28,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          color: colors.accent,
          child: CardSmallText(title, color: colors.onAccent, size: 9),
        ),
      ),
    Positioned(
      left: 18,
      right: 90,
      top: 58,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 22, color: colors.ink),
        CardSmallText(data.company, color: colors.inkSoft),
      ]),
    ),
    Positioned(right: 20, top: 54, child: CardAvatar(data: data, radius: 26, background: colors.rule, foreground: colors.ink, onTap: onAvatarTap)),
    Positioned(
      left: 18,
      right: 18,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.inkSoft, width: 0.6))),
        child: CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ),
    ),
  ]);
}

/// 水墨：右邊一個淡淡的大墨圈，名字用主題色
Widget buildInkFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(
      right: 18,
      top: 22,
      child: Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.accent.withValues(alpha: 0.16), width: 12)),
      ),
    ),
    Positioned(right: 48, top: 52, child: CardAvatar(data: data, radius: 28, background: colors.accent.withValues(alpha: 0.1), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      left: 24,
      right: 160,
      top: 60,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 22, color: colors.accent),
        CardSmallText(cardTitleLine(data), color: colors.inkSoft, size: 10),
      ]),
    ),
    Positioned(
      left: 24,
      right: 24,
      bottom: 16,
      child: CardSmallText([data.company, ...cardContactLines(data, maxItems: 1)].where((String part) => part.isNotEmpty).join('　'), color: colors.inkSoft),
    ),
  ]);
}

/// 條紋：上方一排主題色條紋
Widget buildStripeFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  final List<Widget> stripes = [];
  for (int index = 0; index < 24; index++) {
    stripes.add(Container(width: 9, color: colors.accent, margin: const EdgeInsets.only(right: 6)));
  }
  return CardCanvas(background: colors.base, children: [
    Positioned(left: 0, right: 0, top: 0, height: 40, child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: double.infinity, child: Row(children: stripes)))),
    Positioned(
      left: 24,
      right: 80,
      top: 60,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 19, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600),
      ]),
    ),
    Positioned(right: 22, top: 56, child: CardAvatar(data: data, radius: 24, background: colors.accent.withValues(alpha: 0.12), foreground: colors.accent, onTap: onAvatarTap)),
    Positioned(
      left: 24,
      right: 24,
      bottom: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.inkSoft, weight: FontWeight.w600),
        CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ]),
    ),
  ]);
}

/// 圓弧：左下一個大圓弧，資料靠右
Widget buildArcFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(left: -70, bottom: -150, child: Container(width: 300, height: 230, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle))),
    Positioned(left: 26, bottom: 18, child: CardAvatar(data: data, radius: 26, background: colors.onAccent.withValues(alpha: 0.2), foreground: colors.onAccent, onTap: onAvatarTap)),
    Positioned(
      right: 24,
      left: 120,
      top: 28,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CardName(name: data.name, size: 20, color: colors.ink, align: TextAlign.right),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10, weight: FontWeight.w600, align: TextAlign.right),
        CardSmallText(data.company, color: colors.inkSoft, align: TextAlign.right),
      ]),
    ),
    Positioned(right: 24, bottom: 18, child: CardContactColumn(data: data, color: colors.inkSoft, maxItems: 2, alignment: CrossAxisAlignment.end)),
  ]);
}

/// 名牌：整面深色底、淺色字，大頭貼有外圈
Widget buildBadgeFront(BusinessCardData data, VoidCallback? onAvatarTap) {
  final CardColorway colors = data.colorway;
  return CardCanvas(background: colors.base, children: [
    Positioned(
      left: 20,
      top: 20,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.accent.withValues(alpha: 0.8), width: 1.5)),
        child: CardAvatar(data: data, radius: 24, background: colors.accent.withValues(alpha: 0.15), foreground: colors.accent, onTap: onAvatarTap),
      ),
    ),
    Positioned(
      left: 90,
      right: 20,
      top: 26,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardName(name: data.name, size: 20, color: colors.ink),
        CardSmallText(cardTitleLine(data), color: colors.accent, size: 10),
      ]),
    ),
    Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardSmallText(data.company, color: colors.ink, weight: FontWeight.w600),
        CardSmallText(cardContactLines(data, maxItems: 2).join('　'), color: colors.inkSoft),
      ]),
    ),
  ]);
}
