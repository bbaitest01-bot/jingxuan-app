import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'walkthrough_step.dart';

/// 一步動畫的時間表（毫秒）：滑鼠移過去 → 點下去 → 換畫面 → 鏡頭移到結果 → 停留閱讀
class WalkthroughTiming {
  static const int moveEnd = 800;
  static const int clickStart = 850;
  static const int clickEnd = 1250;
  static const int imageChangeStart = 1000;
  static const int imageChangeEnd = 1300;
  static const int cameraAfterStart = 1250;
  static const int cameraAfterEnd = 1800;
  // 這一步的畫面和上一步結束時不同（換場景）時，前面這段時間淡入
  static const int sceneFadeEnd = 350;
  // 頁面往下捲：滑鼠到定位後開始，慢慢捲到底
  static const int scrollEnd = moveEnd + 3200;

  /// 這一步總共多久：最後一個動作做完，再停留 holdMilliseconds 就接下一步，不空等（沛沛 2026-11-08）
  static int totalOf(WalkthroughStep step) {
    int lastActionEnd = moveEnd;
    if (step.action == WalkthroughAction.click) lastActionEnd = clickEnd;
    if (step.imageAfter != null) lastActionEnd = imageChangeEnd;
    if (!step.camera.isSameAs(step.cameraAfter)) lastActionEnd = cameraAfterEnd;
    if (step.scroll != null) lastActionEnd = scrollEnd;
    return lastActionEnd + step.holdMilliseconds;
  }
}

/// 舞台：真實截圖＋鏡頭放大＋滑鼠＋點擊波紋。
/// 畫面完全由 [elapsedMilliseconds]（這一步播到第幾毫秒）算出來，所以暫停、換步都不會亂
class WalkthroughStage extends StatelessWidget {
  final WalkthroughStep step;
  final Offset cursorStart;
  final WalkthroughCamera cameraStart;
  final double elapsedMilliseconds;

  /// 上一步結束時的畫面；和這一步開頭不同時會淡出（第一步是 null）
  final String? previousImage;

  const WalkthroughStage({
    super.key,
    required this.step,
    required this.cursorStart,
    required this.cameraStart,
    required this.elapsedMilliseconds,
    this.previousImage,
  });

  // 算出 from～to 這段時間裡的進度（0～1），並加上緩動讓動作不生硬
  double _progressBetween(int from, int to) {
    final double raw = ((elapsedMilliseconds - from) / (to - from)).clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(raw);
  }

  WalkthroughCamera _currentCamera() {
    final double zoomInProgress = _progressBetween(0, WalkthroughTiming.moveEnd);
    final double afterProgress = _progressBetween(WalkthroughTiming.cameraAfterStart, WalkthroughTiming.cameraAfterEnd);
    final Offset centerDuringMove = Offset.lerp(cameraStart.center, step.camera.center, zoomInProgress)!;
    final double zoomDuringMove = lerpDouble(cameraStart.zoom, step.camera.zoom, zoomInProgress)!;
    return WalkthroughCamera(
      Offset.lerp(centerDuringMove, step.cameraAfter.center, afterProgress)!,
      lerpDouble(zoomDuringMove, step.cameraAfter.zoom, afterProgress)!,
    );
  }

  // 鏡頭左上角在畫面的哪裡；靠邊時不讓鏡頭超出截圖範圍
  Offset _cameraTopLeft(WalkthroughCamera camera) {
    final double visibleFraction = 1 / camera.zoom;
    final double left = (camera.center.dx - visibleFraction / 2).clamp(0.0, 1 - visibleFraction);
    final double top = (camera.center.dy - visibleFraction / 2).clamp(0.0, 1 - visibleFraction);
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return LayoutBuilder(
      builder: (BuildContext layoutContext, BoxConstraints constraints) {
        final Size stageSize = constraints.biggest;
        final WalkthroughCamera camera = _currentCamera();
        final Offset topLeft = _cameraTopLeft(camera);

        // 滑鼠在截圖上的位置，換算成舞台上的位置（滑鼠本身不跟著放大）
        final Offset cursorFraction =
            Offset.lerp(cursorStart, step.target, _progressBetween(0, WalkthroughTiming.moveEnd))!;
        final Offset cursorOnStage = Offset(
          (cursorFraction.dx - topLeft.dx) * camera.zoom * stageSize.width,
          (cursorFraction.dy - topLeft.dy) * camera.zoom * stageSize.height,
        );

        final bool isClick = step.action == WalkthroughAction.click;
        final double clickProgress = isClick
            ? ((elapsedMilliseconds - WalkthroughTiming.clickStart) /
                    (WalkthroughTiming.clickEnd - WalkthroughTiming.clickStart))
                .clamp(0.0, 1.0)
            : 0;
        final bool isRippleVisible = clickProgress > 0 && clickProgress < 1;
        final double cursorPressScale = isRippleVisible ? 0.85 : 1;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -topLeft.dx * camera.zoom * stageSize.width,
                top: -topLeft.dy * camera.zoom * stageSize.height,
                width: stageSize.width * camera.zoom,
                height: stageSize.height * camera.zoom,
                child: _StageImages(
                  step: step,
                  imageChangeProgress: _progressBetween(
                    WalkthroughTiming.imageChangeStart,
                    WalkthroughTiming.imageChangeEnd,
                  ),
                  previousImage: previousImage,
                  sceneFadeProgress: _progressBetween(0, WalkthroughTiming.sceneFadeEnd),
                  scrollProgress: _progressBetween(WalkthroughTiming.moveEnd, WalkthroughTiming.scrollEnd),
                ),
              ),
              if (isRippleVisible)
                Positioned(
                  left: cursorOnStage.dx - 28,
                  top: cursorOnStage.dy - 28,
                  width: 56,
                  height: 56,
                  child: CustomPaint(painter: _ClickRipplePainter(progress: clickProgress, color: colors.acc)),
                ),
              Positioned(
                left: cursorOnStage.dx - 2,
                top: cursorOnStage.dy - 2,
                width: 26,
                height: 32,
                child: Transform.scale(
                  scale: cursorPressScale,
                  alignment: Alignment.topLeft,
                  child: CustomPaint(painter: _CursorPainter(fillColor: colors.acc, outlineColor: colors.onAcc)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 操作前的截圖，上面疊操作後的截圖並慢慢淡入
class _StageImages extends StatelessWidget {
  final WalkthroughStep step;
  final double imageChangeProgress;
  final String? previousImage;
  final double sceneFadeProgress;
  final double scrollProgress;

  const _StageImages({
    required this.step,
    required this.imageChangeProgress,
    required this.previousImage,
    required this.sceneFadeProgress,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageAfter = step.imageAfter;
    final String? fadingImage = previousImage;
    final WalkthroughScroll? scroll = step.scroll;
    final bool isChangingScene = fadingImage != null && fadingImage != step.image && sceneFadeProgress < 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(step.image, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.high),
        if (isChangingScene)
          Opacity(
            opacity: 1 - sceneFadeProgress,
            child: Image.asset(fadingImage, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.high),
          ),
        if (imageAfter != null && imageChangeProgress > 0)
          Opacity(
            opacity: imageChangeProgress,
            child: Image.asset(imageAfter, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.high),
          ),
        if (scroll != null) _ScrollingStrip(scroll: scroll, progress: scrollProgress),
      ],
    );
  }
}

/// 蓋在內容區上的長圖，依 [progress]（0～1）由上往下捲到底
class _ScrollingStrip extends StatelessWidget {
  final WalkthroughScroll scroll;
  final double progress;

  const _ScrollingStrip({required this.scroll, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext layoutContext, BoxConstraints constraints) {
        final double regionWidth = constraints.maxWidth * scroll.region.width;
        final double regionHeight = constraints.maxHeight * scroll.region.height;
        final double stripHeight = regionWidth / scroll.stripAspectRatio;
        final double scrollDistance = stripHeight - regionHeight;

        return Stack(
          children: [
            Positioned(
              left: constraints.maxWidth * scroll.region.left,
              top: constraints.maxHeight * scroll.region.top,
              width: regionWidth,
              height: regionHeight,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: 0,
                      top: -scrollDistance * progress,
                      width: regionWidth,
                      height: stripHeight,
                      child: Image.asset(
                        scroll.stripImage,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 滑鼠箭頭（尖端在左上角，就是真正點到的位置）
class _CursorPainter extends CustomPainter {
  final Color fillColor;
  final Color outlineColor;

  const _CursorPainter({required this.fillColor, required this.outlineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Path arrow = Path()
      ..moveTo(2, 2)
      ..lineTo(2, 24)
      ..lineTo(8, 19)
      ..lineTo(12, 29)
      ..lineTo(16.5, 27)
      ..lineTo(12.5, 17.5)
      ..lineTo(20, 17)
      ..close();
    canvas.drawPath(arrow, Paint()..color = fillColor);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor || oldDelegate.outlineColor != outlineColor;
  }
}

/// 點擊時從滑鼠尖端往外擴散的光圈
class _ClickRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ClickRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 * progress;
    final double opacity = 1 - progress;
    canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: 0.28 * opacity));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.9 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ClickRipplePainter oldDelegate) => oldDelegate.progress != progress;
}
