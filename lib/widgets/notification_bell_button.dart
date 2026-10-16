import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'notification_arrival_card.dart';
import 'notification_bell_controller.dart';
import 'notification_center_popover.dart';

/// 頂欄的通知鈴鐺：有未讀時右上角顯示紅色數字（超過 99 顯示 99+）；
/// 收到 [NotificationBellController.ring] 時搖一下、數字彈一下
class NotificationBellButton extends StatefulWidget {
  final Color? iconColor;

  const NotificationBellButton({super.key, this.iconColor});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  final NotificationBellController _bellController = NotificationBellController.instance;
  final GlobalKey _bellKey = GlobalKey();
  late final AnimationController _ringController;

  // 搖晃角度（弧度）：左右擺動、越來越小
  static final Animatable<double> _swingAngle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 0.28), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.28, end: -0.22), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.14), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.14, end: -0.07), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.07, end: 0), weight: 1),
  ]);
  // 數字彈一下：放大再縮回
  static final Animatable<double> _badgeScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.45), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 1), weight: 3),
  ]);

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _bellController.registerBell(_bellKey);
    _bellController.ringSignal.addListener(_ring);
  }

  @override
  void dispose() {
    _bellController.ringSignal.removeListener(_ring);
    _bellController.unregisterBell(_bellKey);
    _ringController.dispose();
    super.dispose();
  }

  void _ring() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _ringController.forward(from: 0);
  }

  // 未讀數：卡片還在畫面上的那幾則先不算
  int _visibleUnreadCount() {
    final Set<String> heldBackIds = _bellController.heldBackIds.value;
    int count = 0;
    for (final AppNotification notification in _service.notifications) {
      if (!notification.isRead && !heldBackIds.contains(notification.id)) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_service, _bellController.heldBackIds, _ringController]),
      builder: (BuildContext context, _) {
        final int unreadCount = _visibleUnreadCount();
        String badgeText = '$unreadCount';
        if (unreadCount > 99) badgeText = '99+';
        final double angle = _swingAngle.evaluate(_ringController);
        final double scale = _badgeScale.evaluate(_ringController);

        return IconButton(
          key: _bellKey,
          tooltip: '通知',
          color: widget.iconColor,
          onPressed: () => NotificationCenterPopover.show(context),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Transform.scale(scale: scale, child: Text(badgeText)),
            child: Transform.rotate(
              angle: angle,
              alignment: const Alignment(0, -0.8),
              child: const Icon(Icons.notifications_none_rounded, size: 24),
            ),
          ),
        );
      },
    );
  }
}

/// 放在主畫面裡（看不見）：登入後開始接收通知；新通知進來時從鈴鐺下方跳出卡片，
/// 時間到收回鈴鐺，按「查看」前往那一篇
class NotificationArrivalWatcher extends StatefulWidget {
  const NotificationArrivalWatcher({super.key});

  @override
  State<NotificationArrivalWatcher> createState() => _NotificationArrivalWatcherState();
}

class _NotificationArrivalWatcherState extends State<NotificationArrivalWatcher> {
  final NotificationService _service = NotificationService();
  final NotificationBellController _bellController = NotificationBellController.instance;
  StreamSubscription<AppNotification>? _arrivalSubscription;
  // 目前畫面上的卡片（同時只放一張）
  OverlayEntry? _cardEntry;
  GlobalKey<NotificationArrivalCardState>? _cardKey;

  @override
  void initState() {
    super.initState();
    _arrivalSubscription = _service.arrivals.listen(_showArrival);
    _service.start();
  }

  @override
  void dispose() {
    _arrivalSubscription?.cancel();
    // 畫面正在關閉，等這一格畫完再拿掉卡片
    final OverlayEntry? leftoverEntry = _cardEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (leftoverEntry != null && leftoverEntry.mounted) leftoverEntry.remove();
      _bellController.releaseAll();
    });
    _service.stop();
    super.dispose();
  }

  void _removeCardEntry(OverlayEntry? entry) {
    if (entry != null && entry.mounted) entry.remove();
    if (_cardEntry == entry) {
      _cardEntry = null;
      _cardKey = null;
    }
  }

  // 新通知：如果正在看那一篇，那一頁自己會提示，鈴鐺搖一下就好
  void _showArrival(AppNotification notification) {
    if (!mounted) return;
    final GoRouter router = GoRouter.of(context);
    final String currentPath = router.routerDelegate.currentConfiguration.uri.path;
    if (notification.linkPath != null && notification.linkPath == currentPath) {
      _bellController.ring();
      return;
    }

    // 舊卡片先收進鈴鐺，新的再出來
    _cardKey?.currentState?.absorb(fast: true);
    _bellController.holdBack(notification.id);
    _bellController.ring();

    final GlobalKey<NotificationArrivalCardState> cardKey = GlobalKey<NotificationArrivalCardState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) => NotificationArrivalCard.positioned(
        overlayContext,
        NotificationArrivalCard(
          key: cardKey,
          notification: notification,
          onAbsorbed: () {
            _removeCardEntry(entry);
            _bellController.release(notification.id);
          },
          onOpen: () => _openFromCard(entry, notification, router),
        ),
      ),
    );
    _cardEntry = entry;
    _cardKey = cardKey;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _openFromCard(OverlayEntry entry, AppNotification notification, GoRouter router) {
    _service.markAsRead(notification.id);
    _removeCardEntry(entry);
    _bellController.release(notification.id, shouldRing: false);
    final String? linkPath = notification.linkPath;
    if (linkPath != null) router.go(linkPath);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
