import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/onboarding_tour_service.dart';
import '../services/onboarding_tour_steps.dart';
import '../theme/app_theme.dart';
import 'tour_target.dart';

/// 新手大導覽的聚光燈畫面（2026-11-01 重做；舊版只有畫面正中間一張卡，沒有指到東西）
///
/// 每一步：先切到那一頁 → 等要指的按鈕出現（資料要讀一下）→ 捲到看得到 →
/// 整個畫面變暗，只在那個按鈕挖一個亮洞，旁邊放說明卡。
/// 找不到要指的東西（例如還沒有客戶）時：改說 emptyBody，或整步跳過。
class OnboardingTourOverlay extends StatefulWidget {
  const OnboardingTourOverlay({super.key});

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay> {
  OnboardingTourService get _tour => OnboardingTourService.instance;

  int? _preparedStepIndex;
  bool _isPreparing = false;
  bool _isTargetMissing = false;
  bool _isEmptyTarget = false;

  /// 每次換步驟加一；還在等上一步時換了步驟，舊的等待就作廢
  int _prepareRound = 0;

  /// 導覽進行中每 0.2 秒重新量一次位置（視窗改大小、畫面還在動時亮洞會跟著走）
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tour.addListener(_onTourChanged);
    if (_tour.isActive) WidgetsBinding.instance.addPostFrameCallback((_) => _onTourChanged());
  }

  @override
  void dispose() {
    _tour.removeListener(_onTourChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTourChanged() {
    if (!mounted) return;
    if (!_tour.isActive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _preparedStepIndex = null;
      setState(() {});
      return;
    }
    if (_tour.stepIndex != _preparedStepIndex) _prepareStep();
  }

  Future<void> _prepareStep() async {
    final int round = ++_prepareRound;
    final OnboardingTourStep step = _tour.currentStep;
    setState(() {
      _preparedStepIndex = _tour.stepIndex;
      _isPreparing = true;
      _isTargetMissing = false;
      _isEmptyTarget = false;
    });

    // 1. 切到這一步的頁面
    final String? route = _routeOf(step);
    final bool needsPayload = step.payloadTargetId != null;
    if (needsPayload && route == null) {
      _tour.skipCurrent();
      return;
    }
    if (route != null) GoRouter.of(context).go(route);

    // 2. 等要指的東西（或空資料提示）出現：最多等 1.5 秒，但只要一出現就立刻結束等待
    bool isFound = step.targetIds.isEmpty;
    bool isEmptyFound = false;
    for (int attempt = 0; attempt < 15 && !isFound; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (round != _prepareRound || !mounted) return;
      if (step.targetIds.isNotEmpty && _targetRectForIds(step.targetIds) != null) {
        isFound = true;
        break;
      }
      // 空帳號防延遲：若頁面已出現空白提示，立刻認定並結束等待（2026-11-01 沛沛反映空帳號卡頓）
      if (step.emptyTargetIds.isNotEmpty && _targetRectForIds(step.emptyTargetIds) != null) {
        isEmptyFound = true;
        isFound = true;
        break;
      }
    }
    if (!isFound && step.skipWhenMissing) {
      _tour.skipCurrent();
      return;
    }

    // 3. 捲到看得到
    final List<String> scrollIds = isEmptyFound ? step.emptyTargetIds : step.targetIds;
    if (isFound && scrollIds.isNotEmpty) {
      final BuildContext? targetContext = TourTarget.contextOf(scrollIds.first);
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(targetContext, alignment: 0.3, duration: const Duration(milliseconds: 250));
      }
    }
    if (round != _prepareRound || !mounted) return;
    setState(() {
      _isPreparing = false;
      _isTargetMissing = !isFound;
      _isEmptyTarget = isEmptyFound;
    });
    _refreshTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  // 這一步要切到的網址；要看別的亮點記的資料（例如客戶編號）卻找不到時回傳 null
  String? _routeOf(OnboardingTourStep step) {
    final String? payloadTargetId = step.payloadTargetId;
    final String Function(String payload)? routeFromPayload = step.routeFromPayload;
    if (payloadTargetId == null || routeFromPayload == null) return step.route;
    final String? payload = TourTarget.payloadOf(payloadTargetId);
    if (payload == null) return null;
    return routeFromPayload(payload);
  }

  // 要亮的地方在這個畫面裡的範圍；好幾個就框成一塊
  Rect? _targetRect(OnboardingTourStep step) {
    if (_isEmptyTarget && step.emptyTargetIds.isNotEmpty) {
      return _targetRectForIds(step.emptyTargetIds);
    }
    return _targetRectForIds(step.targetIds);
  }

  Rect? _targetRectForIds(List<String> ids) {
    final RenderObject? overlayBox = context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return null;
    final Offset overlayOrigin = overlayBox.localToGlobal(Offset.zero);
    Rect? result;
    for (final String targetId in ids) {
      final Rect? rect = TourTarget.rectOf(targetId);
      if (rect == null) continue;
      final Rect localRect = rect.shift(-overlayOrigin);
      if (result == null) {
        result = localRect;
      } else {
        result = result.expandToInclude(localRect);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_tour.isActive) return const SizedBox.shrink();
    final AppColors colors = context.appColors;
    final OnboardingTourStep step = _tour.currentStep;
    Rect? hole;
    if (!_isPreparing && !_isTargetMissing) hole = _targetRect(step);
    String body = step.body;
    if (_isEmptyTarget || _isTargetMissing) body = step.emptyBody ?? step.body;

    return Stack(
      children: [
        // 擋住底下的點擊：導覽進行中不讓使用者點到別的地方而跳頁
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _SpotlightPainter(hole: hole, ringColor: colors.warn)),
          ),
        ),
        if (!_isPreparing)
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _TourCardLayout(hole: hole),
              child: _TourCard(step: step, body: body),
            ),
          ),
      ],
    );
  }
}

/// 整個畫面變暗，只在 [hole] 挖一個亮洞，外面一圈橘框
class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final Color ringColor;

  _SpotlightPainter({required this.hole, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Path dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final Rect? holeRect = hole;
    RRect? holeShape;
    if (holeRect != null) {
      holeShape = RRect.fromRectAndRadius(holeRect.inflate(6), const Radius.circular(10));
      dimPath.addRRect(holeShape);
    }
    // 遮罩一定是半透明黑（深淺模式都一樣），所以不用主題色
    canvas.drawPath(dimPath, Paint()..color = Colors.black.withValues(alpha: 0.55));
    if (holeShape != null) {
      final Paint ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(holeShape, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}

/// 說明卡放哪裡：亮洞右邊 → 下面 → 上面 → 左邊，都放不下就放畫面下方；沒有亮洞就放正中間
class _TourCardLayout extends SingleChildLayoutDelegate {
  final Rect? hole;

  _TourCardLayout({required this.hole});

  static const double _margin = 16;
  static const double _gap = 16;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double width = math.min(340, constraints.maxWidth - _margin * 2);
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: constraints.maxHeight - _margin * 2);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Rect? holeRect = hole;
    final double centerX = (size.width - childSize.width) / 2;
    if (holeRect == null) return Offset(centerX, (size.height - childSize.height) / 2);

    double clampX(double x) => x.clamp(_margin, size.width - childSize.width - _margin).toDouble();
    double clampY(double y) => y.clamp(_margin, size.height - childSize.height - _margin).toDouble();
    final double besideX = holeRect.center.dx - childSize.width / 2;

    if (holeRect.right + _gap + childSize.width <= size.width - _margin) {
      return Offset(holeRect.right + _gap, clampY(holeRect.top));
    }
    if (holeRect.bottom + _gap + childSize.height <= size.height - _margin) {
      return Offset(clampX(besideX), holeRect.bottom + _gap);
    }
    if (holeRect.top - _gap - childSize.height >= _margin) {
      return Offset(clampX(besideX), holeRect.top - _gap - childSize.height);
    }
    if (holeRect.left - _gap - childSize.width >= _margin) {
      return Offset(holeRect.left - _gap - childSize.width, clampY(holeRect.top));
    }
    return Offset(clampX(centerX), size.height - childSize.height - _margin);
  }

  @override
  bool shouldRelayout(covariant _TourCardLayout oldDelegate) => oldDelegate.hole != hole;
}

/// 說明卡：第幾步、標題、說明、略過／上一步／下一步
class _TourCard extends StatelessWidget {
  final OnboardingTourStep step;
  final String body;

  const _TourCard({required this.step, required this.body});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final OnboardingTourService tour = OnboardingTourService.instance;
    String nextLabel = step.nextButtonLabel ?? (tour.isLastStep ? '開始使用' : '下一步');
    return Material(
      color: colors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    step.section,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.acc),
                  ),
                ),
                const Spacer(),
                Text(
                  '${tour.stepIndex + 1} / ${tour.stepCount}',
                  style: AppTextStyles.mono(fontSize: 12, color: colors.ink3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(step.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.ink)),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(fontSize: 14, height: 1.6, color: colors.ink2)),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!tour.isLastStep)
                  TextButton(
                    onPressed: tour.finish,
                    child: Text('略過導覽', style: TextStyle(color: colors.ink3)),
                  ),
                const Spacer(),
                if (!tour.isFirstStep) TextButton(onPressed: tour.previous, child: const Text('上一步')),
                const SizedBox(width: 4),
                FilledButton(onPressed: tour.next, child: Text(nextLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
