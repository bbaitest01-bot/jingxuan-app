import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'business_card_drawer.dart';
import 'business_card_export.dart';
import 'business_card_faces.dart';
import 'profile_editor_state.dart';

/// 名片展示台（2026-10-31 沛沛：要有酷的感覺）
///
/// - 滑鼠移到名片上：名片跟著滑鼠方向立體傾斜，表面有一道跟著移動的反光
/// - 手機：用手指拖名片也會傾斜
/// - 點一下：3D 翻到背面（2026-10-31 沛沛：點了就會翻，不需要另一個翻面按鈕）
/// - 下面：下載名片（正反面同一張圖）、這個模板的配色、模板抽屜
/// 傾斜只重畫這一塊，不會整頁重畫。
class BusinessCardStage extends StatefulWidget {
  final ProfileEditorState editor;
  final VoidCallback onAvatarTap;

  const BusinessCardStage({super.key, required this.editor, required this.onAvatarTap});

  @override
  State<BusinessCardStage> createState() => _BusinessCardStageState();
}

class _BusinessCardStageState extends State<BusinessCardStage> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;

  // 傾斜角度（弧度）與反光位置（0～1）
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> _glare = ValueNotifier(const Offset(0.5, 0.3));

  static const double _maxTilt = 0.22;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tilt.dispose();
    _glare.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipController.value < 0.5) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  // 指標在名片上的位置（0～1）換成傾斜角度與反光位置
  void _pointAt(Offset localPosition, Size size) {
    final double x = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final double y = (localPosition.dy / size.height).clamp(0.0, 1.0);
    _tilt.value = Offset((0.5 - y) * _maxTilt * 2, (x - 0.5) * _maxTilt * 2);
    _glare.value = Offset(x, y);
  }

  void _resetTilt() {
    _tilt.value = Offset.zero;
    _glare.value = const Offset(0.5, 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: businessCardSize.width / businessCardSize.height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = constraints.biggest;
              return MouseRegion(
                onHover: (PointerHoverEvent event) => _pointAt(event.localPosition, size),
                onExit: (PointerExitEvent event) => _resetTilt(),
                child: GestureDetector(
                  onTap: _flip,
                  onPanUpdate: (DragUpdateDetails details) => _pointAt(details.localPosition, size),
                  onPanEnd: (DragEndDetails details) => _resetTilt(),
                  child: _buildCard(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '滑鼠移上去名片會傾斜、反光；點一下翻面',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: colors.ink3),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: () => showBusinessCardDownload(context, widget.editor.cardData),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('下載名片'),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.editor,
          builder: (BuildContext context, Widget? child) => BusinessCardColorways(editor: widget.editor),
        ),
        const SizedBox(height: 18),
        Text('換一個模板', style: TextStyle(fontSize: 12, color: colors.ink2)),
        ListenableBuilder(
          listenable: widget.editor,
          builder: (BuildContext context, Widget? child) => BusinessCardDrawer(editor: widget.editor),
        ),
      ],
    );
  }

  // 傾斜、翻面、反光疊在一起；只有這一塊跟著滑鼠重畫
  Widget _buildCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_tilt, _flipController, widget.editor]),
      builder: (BuildContext context, Widget? child) {
        final double flipAngle = Curves.easeInOutCubic.transform(_flipController.value) * math.pi;
        final bool showBack = flipAngle > math.pi / 2;
        final BusinessCardData data = widget.editor.cardData;
        Widget face = BusinessCardFront(data: data, onAvatarTap: widget.onAvatarTap);
        if (showBack) {
          // 背面要先左右反過來，翻過去之後看起來才是正的
          face = Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: BusinessCardBack(data: data),
          );
        }
        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(_tilt.value.dx)
          ..rotateY(_tilt.value.dy + flipAngle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: data.colorway.accent.withValues(alpha: 0.28), blurRadius: 28, offset: const Offset(0, 16)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: FittedBox(fit: BoxFit.contain, child: face)),
                Positioned.fill(child: _Glare(glare: _glare)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 反光：一團淡淡的白光跟著滑鼠移動
class _Glare extends StatelessWidget {
  final ValueNotifier<Offset> glare;

  const _Glare({required this.glare});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Offset>(
        valueListenable: glare,
        builder: (BuildContext context, Offset position, Widget? child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(position.dx * 2 - 1, position.dy * 2 - 1),
                  radius: 0.9,
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                    const Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
