import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'card_templates/card_template.dart';
import 'profile_editor_state.dart';

export 'card_templates/card_template.dart' show businessCardSize;

/// 名片正面：照選的模板排（2026-10-31 改成模板，見 `card_templates/`）
class BusinessCardFront extends StatelessWidget {
  final BusinessCardData data;

  /// 點大頭貼換照片（下載圖片、模板抽屜裡的小卡不需要，傳 null）
  final VoidCallback? onAvatarTap;

  const BusinessCardFront({super.key, required this.data, this.onAvatarTap});

  @override
  Widget build(BuildContext context) => data.template.buildFront(data, onAvatarTap);
}

/// 名片背面：跟正面配套的風格（整面主題色／細線／雙線框／報紙雙線／墨圈），
/// 左邊服務理念與證照徽章，右邊 LINE QR Code（有上傳才顯示）
class BusinessCardBack extends StatelessWidget {
  final BusinessCardData data;

  const BusinessCardBack({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final CardColorway colors = data.colorway;
    final CardBackStyle style = data.template.backStyle;
    // 整面主題色時，字改用放在主題色上的顏色
    Color background = colors.base;
    Color textColor = colors.ink;
    Color softColor = colors.inkSoft;
    if (style == CardBackStyle.accentFill) {
      background = colors.accent;
      textColor = colors.onAccent;
      softColor = colors.onAccent.withValues(alpha: 0.7);
    }
    final ImageProvider? qrCode = data.qrCode;

    return CardCanvas(background: background, children: [
      ..._decorations(style, colors),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _BackText(data: data, textColor: textColor, softColor: softColor)),
              if (qrCode != null) ...[
                const SizedBox(width: 16),
                _QrBlock(qrCode: qrCode, captionColor: softColor),
              ],
            ],
          ),
        ),
      ),
    ]);
  }

  // 每種背面風格的裝飾
  List<Widget> _decorations(CardBackStyle style, CardColorway colors) {
    if (style == CardBackStyle.lines) {
      return [
        Positioned(left: 24, right: 24, top: 14, child: Container(height: 0.6, color: colors.accent)),
        Positioned(left: 24, right: 24, bottom: 12, child: Container(height: 0.6, color: colors.accent)),
      ];
    }
    if (style == CardBackStyle.frame) {
      return [
        Positioned.fill(child: Padding(padding: const EdgeInsets.all(9), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: colors.accent, width: 1))))),
        Positioned.fill(child: Padding(padding: const EdgeInsets.all(13), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: colors.accent, width: 0.5))))),
      ];
    }
    if (style == CardBackStyle.newspaper) {
      return [
        Positioned(
          left: 18,
          right: 18,
          top: 12,
          child: Column(children: [Container(height: 2, color: colors.ink), const SizedBox(height: 2), Container(height: 0.6, color: colors.ink)]),
        ),
      ];
    }
    if (style == CardBackStyle.inkCircle) {
      return [
        Positioned(
          left: -40,
          bottom: -50,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.accent.withValues(alpha: 0.12), width: 16)),
          ),
        ),
      ];
    }
    return [];
  }
}

class _BackText extends StatelessWidget {
  final BusinessCardData data;
  final Color textColor;
  final Color softColor;

  const _BackText({required this.data, required this.textColor, required this.softColor});

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = [];
    for (final String badge in data.badges.take(4)) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: softColor, width: 0.7),
        ),
        child: Text(badge, style: TextStyle(fontSize: 8.5, color: textColor)),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.bio.isNotEmpty) ...[
          Text('服務理念', style: TextStyle(fontSize: 9, color: softColor, letterSpacing: 3)),
          const SizedBox(height: 6),
          Text(
            data.bio,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.serif(fontSize: 12, color: textColor).copyWith(height: 1.6),
          ),
        ],
        const Spacer(),
        if (badges.isNotEmpty) Wrap(spacing: 5, runSpacing: 5, children: badges),
        const SizedBox(height: 8),
        CardSmallText(data.company, color: softColor, letterSpacing: 1.5),
      ],
    );
  }
}

class _QrBlock extends StatelessWidget {
  final ImageProvider qrCode;
  final Color captionColor;

  const _QrBlock({required this.qrCode, required this.captionColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(6)),
          child: Image(
            image: qrCode,
            fit: BoxFit.contain,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const Icon(Icons.qr_code_2_rounded),
          ),
        ),
        const SizedBox(height: 6),
        Text('掃碼加 LINE', style: TextStyle(fontSize: 9, color: captionColor, letterSpacing: 1)),
      ],
    );
  }
}
