import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/app_theme.dart';
import 'business_card_faces.dart';
import 'card_templates/card_template.dart';
import 'card_templates/card_template_registry.dart';
import 'profile_editor_state.dart';

/// 名片模板抽屜（2026-10-31 沛沛的點子）
///
/// 模板像抽屜裡排滿的文件，只露出上半部；滑鼠（或手指）滑過時，靠近的幾張依距離浮起，
/// 像翻文件一樣「刷刷刷」流過去；選中的那張一直升著。每張小卡就是用自己的資料套上那個模板。
class BusinessCardDrawer extends StatefulWidget {
  final ProfileEditorState editor;

  const BusinessCardDrawer({super.key, required this.editor});

  @override
  State<BusinessCardDrawer> createState() => _BusinessCardDrawerState();
}

class _BusinessCardDrawerState extends State<BusinessCardDrawer>
    with SingleTickerProviderStateMixin {
  static const double _cardWidth = 112;
  static const double _cardHeight = _cardWidth * 3 / 5;
  static const double _drawerHeight = 92;

  /// 沒被碰到時，卡片有多少藏在抽屜裡
  static const double _restDrop = 14;
  static const double _hoverLift = 28;
  static const double _selectedLift = 22;

  late final Ticker _ticker;
  late List<double> _lifts;
  double? _pointerX;
  List<double> _cardCenters = [];

  List<CardTemplate> get _templates => CardTemplateRegistry.all;

  @override
  void initState() {
    super.initState();
    _lifts = List.filled(_templates.length, 0);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // 每一格：每張卡往「該浮多高」靠近一點，所以起伏是滑順的
  void _onTick(Duration elapsed) {
    bool anyMoving = false;
    for (int index = 0; index < _templates.length; index++) {
      final double target = _targetLift(index);
      final double difference = target - _lifts[index];
      if (difference.abs() > 0.3) {
        _lifts[index] += difference * 0.2;
        anyMoving = true;
      } else {
        _lifts[index] = target;
      }
    }
    if (anyMoving) setState(() {});
  }

  // 離指標越近浮越高；選中的一直升著
  double _targetLift(int index) {
    double lift = 0;
    final double? pointer = _pointerX;
    if (pointer != null && index < _cardCenters.length) {
      final double distance = (pointer - _cardCenters[index]).abs();
      lift = math.max(0, _hoverLift - distance * 0.45);
    }
    if (_templates[index].key == widget.editor.templateKey) {
      lift = math.max(lift, _selectedLift);
    }
    return lift;
  }

  void _pointAt(double x) => _pointerX = x;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = _templates.length;
        // 卡片之間的間距：寬的時候攤開一點，窄的時候疊多一點；手機太窄就改成可以左右滑
        final double fittedStep =
            (constraints.maxWidth - _cardWidth - 16) / (count - 1);
        final double step =
            fittedStep.clamp(18.0, _cardWidth * 0.62).toDouble();
        final double contentWidth = _cardWidth + step * (count - 1) + 16;
        _cardCenters = List.generate(
            count, (int index) => 8 + index * step + _cardWidth / 2);

        final Widget drawer = SizedBox(
          width: math.max(contentWidth, constraints.maxWidth),
          height: _drawerHeight,
          child: MouseRegion(
            onHover: (PointerHoverEvent event) =>
                _pointAt(event.localPosition.dx),
            onExit: (PointerExitEvent event) => _pointerX = null,
            child: Listener(
              onPointerMove: (PointerMoveEvent event) =>
                  _pointAt(event.localPosition.dx),
              onPointerUp: (PointerUpEvent event) => _pointerX = null,
              // 超出抽屜口（底線以下）的部分切掉
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int index = 0; index < count; index++)
                      _buildCard(index, step),
                    // 抽屜口：一條細線，卡片下半部乾淨地切在線下（2026-10-31 沛沛：白色前板突兀、漸層糊糊的都不要）
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 1.2,
                        child: ColoredBox(
                            color: colors.ink3.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ),
        );
        if (contentWidth <= constraints.maxWidth) return drawer;
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal, child: drawer);
      },
    );
  }

  Widget _buildCard(int index, double step) {
    final CardTemplate template = _templates[index];
    final ProfileEditorState editor = widget.editor;
    final bool isSelected = template.key == editor.templateKey;
    CardColorway colorway = template.colorways.first;
    if (isSelected) colorway = editor.colorway;
    final BusinessCardData data =
        editor.cardData.withTemplate(template, colorway);
    final AppColors colors = context.appColors;

    return Positioned(
      left: 8 + index * step,
      // 平常下半部藏在抽屜口底線以下，浮起時才整張露出來
      bottom: -_restDrop + _lifts[index],
      width: _cardWidth,
      height: _cardHeight,
      child: GestureDetector(
        onTap: () => editor.selectTemplate(template.key),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: isSelected ? colors.warn : colors.line,
                  width: isSelected ? 2 : 0.6),
              boxShadow: [
                BoxShadow(
                    color: colors.ink.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, -2))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Positioned.fill(
                      child: IgnorePointer(
                          child:
                              FittedBox(child: BusinessCardFront(data: data)))),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text(template.label,
                          style: TextStyle(fontSize: 9, color: colors.ink2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 這個模板的幾組配色（選了模板才看得到它自己的配色）
class BusinessCardColorways extends StatelessWidget {
  final ProfileEditorState editor;

  const BusinessCardColorways({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final CardTemplate template = editor.template;
    final List<Widget> dots = [];
    for (int index = 0; index < template.colorways.length; index++) {
      final CardColorway colorway = template.colorways[index];
      final bool isSelected = index == editor.colorwayIndex;
      dots.add(InkWell(
        onTap: () => editor.selectColorway(index),
        customBorder: const CircleBorder(),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: isSelected ? colors.warn : colors.line,
                width: isSelected ? 2.5 : 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorway.accent,
                colorway.accent,
                colorway.base,
                colorway.base
              ],
              stops: const [0, 0.5, 0.5, 1],
            ),
          ),
        ),
      ));
    }
    return Row(
      children: [
        Text('「${template.label}」的配色',
            style: TextStyle(fontSize: 12, color: colors.ink2)),
        const SizedBox(width: 12),
        ...dots,
      ],
    );
  }
}
