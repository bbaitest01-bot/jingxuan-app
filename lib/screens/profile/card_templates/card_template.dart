import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../profile_editor_state.dart';

/// 名片的固定尺寸（台灣名片 9 × 5.4 公分＝5:3）；畫面上等比例縮放，下載時放大 3 倍
const Size businessCardSize = Size(360, 216);

/// 一組名片配色：主題色＋底色（2026-10-31 沛沛：每個模板有自己配好的幾組顏色，不讓使用者亂配）
///
/// 名片是印給客戶看的「內容」，不跟 App 的明暗模式變，所以顏色固定寫在模板裡。
class CardColorway {
  final Color accent;
  final Color base;

  const CardColorway(this.accent, this.base);

  /// 底色是深色時，字要用淺色
  bool get isDarkBase => base.computeLuminance() < 0.25;

  Color get ink {
    if (isDarkBase) return const Color(0xFFF1EFE8);
    return const Color(0xFF161E29);
  }

  Color get inkSoft {
    if (isDarkBase) return const Color(0xFFB9B7AE);
    return const Color(0xFF5F5E5A);
  }

  Color get rule {
    if (isDarkBase) return const Color(0x55FFFFFF);
    return const Color(0xFFD3D1C7);
  }

  /// 放在主題色上的字
  Color get onAccent {
    if (accent.computeLuminance() > 0.5) return const Color(0xFF161E29);
    return const Color(0xFFFBFAF7);
  }
}

/// 名片背面的風格（每個模板配一種，背面不再是整面單色）
enum CardBackStyle {
  /// 整面主題色
  accentFill,

  /// 底色＋上下主題色細線
  lines,

  /// 底色＋雙線框
  frame,

  /// 底色＋報紙雙線
  newspaper,

  /// 底色＋淡淡的大圓圈
  inkCircle,
}

/// 一個名片模板：正面怎麼排、背面用哪種風格、有哪幾組配色
class CardTemplate {
  final String key;
  final String label;
  final List<CardColorway> colorways;
  final CardBackStyle backStyle;
  final Widget Function(BusinessCardData data, VoidCallback? onAvatarTap) buildFront;

  const CardTemplate({
    required this.key,
    required this.label,
    required this.colorways,
    required this.backStyle,
    required this.buildFront,
  });
}

// ---- 每個模板都會用到的小零件 ----

/// 名字是英文（只有英文字母、空白、點）
bool isLatinName(String name) => RegExp(r'^[A-Za-z .\-]+$').hasMatch(name);

/// 名字：中文用宋體、字距拉開；英文用細黑體（宋體的英文不好看，2026-10-31 沛沛）
class CardName extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final TextAlign align;

  const CardName({super.key, required this.name, required this.size, required this.color, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    String text = name;
    Color textColor = color;
    // 還沒填名字時淡淡提示，不放假名字
    if (text.isEmpty) {
      text = '姓名';
      textColor = color.withValues(alpha: 0.3);
    }
    TextStyle style = AppTextStyles.serif(fontSize: size, color: textColor).copyWith(letterSpacing: size * 0.2);
    if (isLatinName(text)) {
      style = TextStyle(fontSize: size * 0.95, color: textColor, fontWeight: FontWeight.w300, letterSpacing: size * 0.08);
    }
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: align, style: style);
  }
}

/// 職稱・頭銜（兩個都沒填就是空字串）
String cardTitleLine(BusinessCardData data) {
  final List<String> parts = [];
  if (data.jobTitle.isNotEmpty) parts.add(data.jobTitle);
  if (data.honorTitle.isNotEmpty) parts.add(data.honorTitle);
  return parts.join('・');
}

/// 聯絡方式：只列有填的，最多 [maxItems] 項，每項一行
List<String> cardContactLines(BusinessCardData data, {int maxItems = 3}) {
  final List<String> lines = [];
  if (data.phone.isNotEmpty) lines.add(data.phone);
  if (data.lineId.isNotEmpty) lines.add('LINE  ${data.lineId}');
  if (data.email.isNotEmpty) lines.add(data.email);
  if (data.website.isNotEmpty) lines.add(data.website);
  if (data.address.isNotEmpty) lines.add(data.address);
  return lines.take(maxItems).toList();
}

/// 一段小字（公司、職稱、聯絡方式都用它，統一大小）
class CardSmallText extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final double letterSpacing;
  final TextAlign align;
  final FontWeight weight;

  const CardSmallText(
    this.text, {
    super.key,
    required this.color,
    this.size = 9.5,
    this.letterSpacing = 0.5,
    this.align = TextAlign.left,
    this.weight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(fontSize: size, color: color, letterSpacing: letterSpacing, height: 1.6, fontWeight: weight),
    );
  }
}

/// 聯絡方式一行一行排
class CardContactColumn extends StatelessWidget {
  final BusinessCardData data;
  final Color color;
  final int maxItems;
  final CrossAxisAlignment alignment;

  const CardContactColumn({
    super.key,
    required this.data,
    required this.color,
    this.maxItems = 3,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    TextAlign align = TextAlign.left;
    if (alignment == CrossAxisAlignment.end) align = TextAlign.right;
    if (alignment == CrossAxisAlignment.center) align = TextAlign.center;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: cardContactLines(data, maxItems: maxItems)
          .map((String line) => CardSmallText(line, color: color, align: align))
          .toList(),
    );
  }
}

/// 大頭貼（點了可以換照片；下載圖片時 onTap 是 null）
class CardAvatar extends StatelessWidget {
  final BusinessCardData data;
  final double radius;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const CardAvatar({
    super.key,
    required this.data,
    required this.radius,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String initial = '';
    if (data.name.isNotEmpty) initial = data.name.substring(0, 1);
    final Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: data.avatar,
      child: data.avatar == null
          ? Text(initial, style: AppTextStyles.serif(fontSize: radius * 0.8, color: foreground))
          : null,
    );
    final VoidCallback? tap = onTap;
    if (tap == null) return avatar;
    return Tooltip(
      message: '更換大頭貼',
      child: InkWell(onTap: tap, customBorder: const CircleBorder(), child: avatar),
    );
  }
}

/// 名片外框：固定大小、底色、圓角；[children] 用 Positioned 自由排
class CardCanvas extends StatelessWidget {
  final Color background;
  final List<Widget> children;

  const CardCanvas({super.key, required this.background, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: businessCardSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(color: background, child: Stack(children: children)),
      ),
    );
  }
}
