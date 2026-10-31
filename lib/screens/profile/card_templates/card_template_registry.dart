import 'package:flutter/material.dart';

import 'card_template.dart';
import 'templates_set_one.dart';
import 'templates_set_three.dart';
import 'templates_set_two.dart';

/// 全部名片模板與各自的三組配色（2026-10-31 沛沛：模板夠多、夠好看，使用者不用自己配色）
///
/// 存進資料庫 `profiles.card_theme` 的格式是「模板代碼:配色編號」，例如 `classic:0`
class CardTemplateRegistry {
  static const List<CardTemplate> all = [
    CardTemplate(
      key: 'classic',
      label: '經典',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildClassicFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFFBFAF7)),
        CardColorway(Color(0xFF0D4A3B), Color(0xFFFBFAF7)),
        CardColorway(Color(0xFF6B2238), Color(0xFFFBFAF7)),
      ],
    ),
    CardTemplate(
      key: 'night',
      label: '夜幕',
      backStyle: CardBackStyle.lines,
      buildFront: buildNightFront,
      colorways: [
        CardColorway(Color(0xFFC9A44C), Color(0xFF1F2228)),
        CardColorway(Color(0xFFB8C4D6), Color(0xFF16233A)),
        CardColorway(Color(0xFFD9B8A6), Color(0xFF2B2024)),
      ],
    ),
    CardTemplate(
      key: 'split',
      label: '分割',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildSplitFront,
      colorways: [
        CardColorway(Color(0xFF185FA5), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF3B6D11), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF993C1D), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'vertical',
      label: '直書',
      backStyle: CardBackStyle.frame,
      buildFront: buildVerticalFront,
      colorways: [
        CardColorway(Color(0xFF8E2B2B), Color(0xFFF4EFE4)),
        CardColorway(Color(0xFF2C3E50), Color(0xFFF2F0EA)),
        CardColorway(Color(0xFF4A5D3A), Color(0xFFF1EEE3)),
      ],
    ),
    CardTemplate(
      key: 'minimal',
      label: '極簡',
      backStyle: CardBackStyle.lines,
      buildFront: buildMinimalFront,
      colorways: [
        CardColorway(Color(0xFF161E29), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF0F6E56), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFFD85A30), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'diagonal',
      label: '斜切',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildDiagonalFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFEEF4FA)),
        CardColorway(Color(0xFF72243E), Color(0xFFFAEFF3)),
        CardColorway(Color(0xFF085041), Color(0xFFEAF6F1)),
      ],
    ),
    CardTemplate(
      key: 'frame',
      label: '金框',
      backStyle: CardBackStyle.frame,
      buildFront: buildFrameFront,
      colorways: [
        CardColorway(Color(0xFFB08D3C), Color(0xFFFBF8F1)),
        CardColorway(Color(0xFF8A8F99), Color(0xFFF7F8FA)),
        CardColorway(Color(0xFF9C6B4E), Color(0xFFFAF5F0)),
      ],
    ),
    CardTemplate(
      key: 'newspaper',
      label: '報紙',
      backStyle: CardBackStyle.newspaper,
      buildFront: buildNewspaperFront,
      colorways: [
        CardColorway(Color(0xFFA32D2D), Color(0xFFE7E8EA)),
        CardColorway(Color(0xFF0C447C), Color(0xFFE7E8EA)),
        CardColorway(Color(0xFF2C2C2A), Color(0xFFE7E8EA)),
      ],
    ),
    CardTemplate(
      key: 'ink',
      label: '水墨',
      backStyle: CardBackStyle.inkCircle,
      buildFront: buildInkFront,
      colorways: [
        CardColorway(Color(0xFF2C2C2A), Color(0xFFF6F4EE)),
        CardColorway(Color(0xFF0C447C), Color(0xFFF4F6F8)),
        CardColorway(Color(0xFF5B3A29), Color(0xFFF7F2EA)),
      ],
    ),
    CardTemplate(
      key: 'stripe',
      label: '條紋',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildStripeFront,
      colorways: [
        CardColorway(Color(0xFF185FA5), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFFBA7517), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF3B6D11), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'arc',
      label: '圓弧',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildArcFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF534AB7), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF0F6E56), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'badge',
      label: '名牌',
      backStyle: CardBackStyle.lines,
      buildFront: buildBadgeFront,
      colorways: [
        CardColorway(Color(0xFF85B7EB), Color(0xFF0C447C)),
        CardColorway(Color(0xFF9FE1CB), Color(0xFF0D4A3B)),
        CardColorway(Color(0xFFD3D1C7), Color(0xFF2C2C2A)),
      ],
    ),
    CardTemplate(
      key: 'two_tone',
      label: '雙色',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildTwoToneFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF6B2238), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF0D4A3B), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'corner',
      label: '角落',
      backStyle: CardBackStyle.lines,
      buildFront: buildCornerFront,
      colorways: [
        CardColorway(Color(0xFFD85A30), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF185FA5), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF3B6D11), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'pill',
      label: '膠囊',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildPillFront,
      colorways: [
        CardColorway(Color(0xFF534AB7), Color(0xFFF7F6FE)),
        CardColorway(Color(0xFF0F6E56), Color(0xFFF2FAF7)),
        CardColorway(Color(0xFF993556), Color(0xFFFDF5F8)),
      ],
    ),
    CardTemplate(
      key: 'dot_grid',
      label: '點格',
      backStyle: CardBackStyle.lines,
      buildFront: buildDotGridFront,
      colorways: [
        CardColorway(Color(0xFF185FA5), Color(0xFFFAFBFD)),
        CardColorway(Color(0xFFBA7517), Color(0xFFFDFBF6)),
        CardColorway(Color(0xFF444441), Color(0xFFFAFAF8)),
      ],
    ),
    CardTemplate(
      key: 'wave',
      label: '波浪',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildWaveFront,
      colorways: [
        CardColorway(Color(0xFF1D6FA8), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF0F6E56), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF7F3F98), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'watermark',
      label: '浮水印',
      backStyle: CardBackStyle.frame,
      buildFront: buildWatermarkFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFFBFAF7)),
        CardColorway(Color(0xFF8E2B2B), Color(0xFFFBF8F4)),
        CardColorway(Color(0xFF2C2C2A), Color(0xFFF7F6F2)),
      ],
    ),
    CardTemplate(
      key: 'sidebar',
      label: '側欄',
      backStyle: CardBackStyle.accentFill,
      buildFront: buildSidebarFront,
      colorways: [
        CardColorway(Color(0xFF0C447C), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF3B6D11), Color(0xFFFFFFFF)),
        CardColorway(Color(0xFF72243E), Color(0xFFFFFFFF)),
      ],
    ),
    CardTemplate(
      key: 'neon',
      label: '霓光',
      backStyle: CardBackStyle.lines,
      buildFront: buildNeonFront,
      colorways: [
        CardColorway(Color(0xFF5DCAA5), Color(0xFF12161C)),
        CardColorway(Color(0xFF85B7EB), Color(0xFF121725)),
        CardColorway(Color(0xFFF0997B), Color(0xFF1A1414)),
      ],
    ),
  ];

  static CardTemplate byKey(String key) {
    for (final CardTemplate template in all) {
      if (template.key == key) return template;
    }
    return all.first;
  }

  /// 讀資料庫的 `card_theme`：新格式「模板:配色」；舊的配色代碼（2026-10-31 以前）換成「經典」的配色
  static (String, int) parse(String? saved) {
    final String value = saved ?? '';
    if (value.contains(':')) {
      final List<String> parts = value.split(':');
      final CardTemplate template = byKey(parts.first);
      final int index = int.tryParse(parts.last) ?? 0;
      return (template.key, index.clamp(0, template.colorways.length - 1));
    }
    if (value == 'emerald' || value == 'forest') return ('classic', 1);
    if (value == 'wine') return ('classic', 2);
    if (value == 'dark_gold' || value == 'graphite') return ('night', 0);
    return ('classic', 0);
  }

  static String format(String templateKey, int colorwayIndex) => '$templateKey:$colorwayIndex';
}
