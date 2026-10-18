import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import 'notification_type_color.dart';
import 'notification_bell_controller.dart';

/// 新通知卡片（4-E3a，沛沛 2026-10-17 看過模型確認）：
/// - 出現在鈴鐺下方，不擋住鈴鐺；白色主題白底、深色主題深底，左側色條（完成綠、失敗紅）
/// - 停留 5 秒（滑鼠移上去暫停），時間到或按 ✕ → 縮小飛進鈴鐺，[onAbsorbed] 讓鈴鐺搖一下、數字 +1
/// - 按「查看」→ [onOpen] 直接打開那一篇
/// - 裝置設定「減少動態效果」時只淡入淡出
class NotificationArrivalCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onAbsorbed;

  const NotificationArrivalCard({super.key, required this.notification, required this.onOpen, required this.onAbsorbed});

  static const Duration showDuration = Duration(seconds: 5);
  static const double cardWidth = 340;
  // 寬度小於這個值時卡片左右撐滿（手機）
  static const double narrowWidth = 600;

  /// 依鈴鐺位置放好卡片：電腦版靠右對齊鈴鐺，手機版左右各留 12
  static Widget positioned(BuildContext overlayContext, Widget card) {
    final Size screenSize = MediaQuery.sizeOf(overlayContext);
    final Rect? bellRect = NotificationBellController.instance.bellRect();
    double top = 64;
    if (bellRect != null) top = bellRect.bottom + 8;

    if (screenSize.width < narrowWidth) {
      return Positioned(top: top, left: 12, right: 12, child: card);
    }
    double right = 12;
    if (bellRect != null) right = (screenSize.width - bellRect.right).clamp(12, screenSize.width).toDouble();
    return Positioned(top: top, right: right, width: cardWidth, child: card);
  }

  @override
  State<NotificationArrivalCard> createState() => NotificationArrivalCardState();
}

class NotificationArrivalCardState extends State<NotificationArrivalCard> with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _lifeController;
  late final AnimationController _exitController;
  // 收回時卡片中心要移到鈴鐺中心的距離
  Offset _offsetToBell = Offset.zero;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _lifeController = AnimationController(vsync: this, duration: NotificationArrivalCard.showDuration);
    _exitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
    _lifeController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) absorb();
    });
    _enterController.forward().then((_) {
      if (mounted && !_isLeaving) _lifeController.forward();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _lifeController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  /// 收進鈴鐺；[fast] 用在新通知把舊卡片擠掉時
  Future<void> absorb({bool fast = false}) async {
    if (_isLeaving || !mounted) return;
    _isLeaving = true;
    _lifeController.stop();
    _offsetToBell = _measureOffsetToBell();
    if (fast) _exitController.duration = const Duration(milliseconds: 380);
    await _exitController.forward();
    widget.onAbsorbed();
  }

  void _open() {
    if (_isLeaving) return;
    _isLeaving = true;
    _lifeController.stop();
    widget.onOpen();
  }

  Offset _measureOffsetToBell() {
    final Rect? bellRect = NotificationBellController.instance.bellRect();
    final RenderObject? renderObject = context.findRenderObject();
    if (bellRect == null || renderObject is! RenderBox || !renderObject.attached) return Offset.zero;
    final Offset cardCenter = renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    return bellRect.center - cardCenter;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      // 滑鼠移上去暫停計時，移開繼續
      onEnter: (_) => _lifeController.stop(),
      onExit: (_) {
        if (!_isLeaving) _lifeController.forward();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _exitController]),
        builder: (BuildContext context, Widget? child) => _applyMotion(child!, reduceMotion),
        child: _CardContent(
          notification: widget.notification,
          lifeProgress: _lifeController,
          onOpen: _open,
          onClose: () => absorb(),
        ),
      ),
    );
  }

  // 進場：從右上（鈴鐺方向）長出來；收回：一邊縮小一邊飛向鈴鐺
  Widget _applyMotion(Widget card, bool reduceMotion) {
    final double enterValue = _enterController.value;
    final double exitValue = Curves.easeInCubic.transform(_exitController.value);
    if (reduceMotion) {
      return Opacity(opacity: (enterValue * (1 - exitValue)).clamp(0, 1).toDouble(), child: card);
    }

    final double enterCurve = Curves.easeOutBack.transform(enterValue);
    final double enterScale = 0.25 + 0.75 * enterCurve;
    final double enterOpacity = enterValue.clamp(0, 1).toDouble();
    Widget result = Transform.scale(scale: enterScale, alignment: Alignment.topRight, child: card);
    result = Opacity(opacity: enterOpacity, child: result);

    if (_exitController.value == 0) return result;
    return Transform.translate(
      offset: _offsetToBell * exitValue,
      child: Transform.scale(
        scale: 1 - 0.96 * exitValue,
        child: Opacity(opacity: 1 - 0.8 * exitValue, child: result),
      ),
    );
  }
}

/// 卡片本身：左側色條、圖示、標題、✕、內容、時間條、「查看」
class _CardContent extends StatelessWidget {
  final AppNotification notification;
  final Animation<double> lifeProgress;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _CardContent({required this.notification, required this.lifeProgress, required this.onOpen, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color toneColor = notificationTypeColor(context, notification.type);
    return Material(
      color: colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: toneColor),
            Expanded(child: _buildBody(colorScheme, toneColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, Color toneColor) {
    final Color mutedColor = colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(notification.type.icon, color: toneColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(notification.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  IconButton(
                    tooltip: '收起',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: mutedColor,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28, right: 6),
                child: Text(notification.content, style: TextStyle(fontSize: 13, height: 1.5, color: mutedColor)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28, right: 6, top: 4),
                child: Row(
                  children: [
                    Text('剛剛', style: TextStyle(fontSize: 11, color: mutedColor)),
                    const Spacer(),
                    if (notification.linkPath != null)
                      TextButton(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: toneColor,
                          backgroundColor: toneColor.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('查看', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 時間條：剩下的停留時間
        AnimatedBuilder(
          animation: lifeProgress,
          builder: (BuildContext context, _) => LinearProgressIndicator(
            value: 1 - lifeProgress.value,
            minHeight: 3,
            color: toneColor.withValues(alpha: 0.7),
            backgroundColor: Colors.transparent,
          ),
        ),
      ],
    );
  }
}
