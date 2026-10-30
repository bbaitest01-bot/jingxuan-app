import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 打開客戶側邊欄時，被點的卡片「咻」一下飛到左邊空白區的正中間（2026-10-30 組長提出）
///
/// 沿一條往上拱的弧線飛過去；關掉側邊欄時 [animation] 倒著跑，卡片飛回它在列表裡的位置。
/// 視窗大小改變時每一格都重新計算：左邊的卡片重新置中、寬度跟著列表的卡片變，
/// 飛回去時也是飛到列表卡片「現在」的位置（2026-10-30 沛沛反映卡片不會跟著視窗調整）。
class CustomerCardFlight extends StatelessWidget {
  final Animation<double> animation;

  /// 點下去那一刻卡片的位置（找不到列表裡的卡片時才用）
  final Rect originRect;

  /// 列表裡那張卡片「現在」的位置；視窗變了位置會跟著變
  final Rect? Function()? currentOriginRect;

  /// 側邊欄寬度：卡片要停在「側邊欄左邊那一塊」的中間
  final double sheetWidth;
  final Widget card;

  /// 頁面內容區離畫面四邊的距離（左邊是選單寬度）；卡片停在內容區扣掉側邊欄的正中間
  final EdgeInsets contentPadding;

  /// 左邊放不放得下卡片有變時通知（放不下＝不顯示飛出來的卡片，列表裡那張要顯示回來）
  final ValueChanged<bool>? onFitChanged;

  const CustomerCardFlight({
    super.key,
    required this.animation,
    required this.originRect,
    required this.sheetWidth,
    required this.card,
    this.currentOriginRect,
    this.contentPadding = EdgeInsets.zero,
    this.onFitChanged,
  });

  // 二次貝茲曲線：起點 → 控制點（拱起的最高處）→ 終點
  static Offset arcPoint(Offset start, Offset end, double progress) {
    final Offset middle = Offset((start.dx + end.dx) / 2, math.min(start.dy, end.dy) - 80);
    final double remaining = 1 - progress;
    return start * (remaining * remaining) + middle * (2 * remaining * progress) + end * (progress * progress);
  }

  /// 左邊空間比這個窄就不飛（卡片縮太小會被切到、看不清楚）
  static const double minLandingWidth = 240;

  /// 這個畫面大小下，左邊放不放得下一張卡片
  static bool fitsLanding(Size screenSize, Size cardSize, double sheetWidth, EdgeInsets contentPadding) {
    return landingRect(screenSize, cardSize, sheetWidth, contentPadding).width >= minLandingWidth;
  }

  /// 卡片停下來的位置：內容區扣掉側邊欄那一塊的正中間；放不下時卡片寬度縮小（左右各留 24）
  static Rect landingRect(Size screenSize, Size cardSize, double sheetWidth, EdgeInsets contentPadding) {
    final Rect area = contentPadding.deflateRect(Offset.zero & screenSize);
    final double freeLeft = area.left;
    final double freeRight = screenSize.width - sheetWidth;
    final double width = math.max(0, math.min(cardSize.width, freeRight - freeLeft - 48));
    final Offset center = Offset((freeLeft + freeRight) / 2, area.center.dy);
    return Rect.fromCenter(center: center, width: width, height: cardSize.height);
  }

  @override
  Widget build(BuildContext context) {
    // 讀畫面大小：視窗一變，這裡就重新計算
    final Size screenSize = MediaQuery.sizeOf(context);
    // 一出發就快、快到終點再減速（2026-10-30 沛沛選：原本慢起步會被感覺成卡一下）
    final Animation<double> curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: curved,
      builder: (BuildContext context, Widget? child) {
        final Rect start = currentOriginRect?.call() ?? originRect;
        final Rect end = landingRect(screenSize, start.size, sheetWidth, contentPadding);
        // 視窗太窄、左邊放不下一張卡片：不顯示飛出來的卡片，只有側邊欄（2026-10-30 沛沛決定）
        final bool fits = end.width >= minLandingWidth;
        final ValueChanged<bool>? fitChanged = onFitChanged;
        if (fitChanged != null) WidgetsBinding.instance.addPostFrameCallback((_) => fitChanged(fits));
        if (!fits) return const SizedBox.shrink();
        final double progress = curved.value;
        final Offset position = arcPoint(start.topLeft, end.topLeft, progress);
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: start.width + (end.width - start.width) * progress,
          height: start.height,
          child: child!,
        );
      },
      // 飛的那張單獨畫，不讓後面整頁跟著重畫
      child: RepaintBoundary(child: IgnorePointer(child: Material(type: MaterialType.transparency, child: card))),
    );
  }
}

/// 動畫跑完才顯示 [child]，跑的時候先顯示 [placeholder]（2026-10-30 沛沛反映飛的時候會卡一下）
///
/// 側邊欄內容很多（三個分頁、表單、讀保單），和飛的動畫擠在同一時間建立會頓一下，
/// 所以先讓卡片飛完、側邊欄滑進來，再放內容。顯示過一次就不再隱藏（關閉時倒著跑也照常顯示）。
class ShowAfterAnimation extends StatefulWidget {
  final Animation<double> animation;
  final Widget placeholder;
  final Widget child;

  const ShowAfterAnimation({super.key, required this.animation, required this.placeholder, required this.child});

  @override
  State<ShowAfterAnimation> createState() => _ShowAfterAnimationState();
}

class _ShowAfterAnimationState extends State<ShowAfterAnimation> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _isReady = widget.animation.status == AnimationStatus.completed;
    widget.animation.addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isReady) {
      setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return widget.placeholder;
    // 內容用 0.2 秒淡入，不會突然跳出來
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (BuildContext context, double opacity, Widget? child) => Opacity(opacity: opacity, child: child),
      child: widget.child,
    );
  }
}
