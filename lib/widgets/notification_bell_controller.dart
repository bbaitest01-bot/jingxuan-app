import 'package:flutter/widgets.dart';

/// 鈴鐺與新通知卡片之間的聯絡（4-E3a）：
/// - 記住畫面上目前的鈴鐺在哪裡，卡片才知道要從哪裡出來、飛回哪裡
/// - 卡片還在畫面上時，那則通知先不算進鈴鐺數字；收進鈴鐺那一刻才 +1（[release]）
/// - [ring] 讓鈴鐺搖一下、數字彈一下
class NotificationBellController {
  static final NotificationBellController instance = NotificationBellController._internal();
  NotificationBellController._internal();

  // 電腦版與手機版各有一個鈴鐺，但同時只會顯示一個；最後出現的那個登記在這裡
  GlobalKey? _bellKey;

  /// 卡片顯示中、先不算進數字的通知編號
  final ValueNotifier<Set<String>> heldBackIds = ValueNotifier<Set<String>>(<String>{});

  /// 每加一，鈴鐺就搖一下
  final ValueNotifier<int> ringSignal = ValueNotifier<int>(0);

  void registerBell(GlobalKey bellKey) => _bellKey = bellKey;

  void unregisterBell(GlobalKey bellKey) {
    if (_bellKey == bellKey) _bellKey = null;
  }

  /// 鈴鐺在整個畫面上的位置；找不到時回傳 null
  Rect? bellRect() {
    final BuildContext? bellContext = _bellKey?.currentContext;
    if (bellContext == null) return null;
    final RenderObject? renderObject = bellContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void holdBack(String notificationId) {
    heldBackIds.value = {...heldBackIds.value, notificationId};
  }

  /// 卡片收進鈴鐺（或被打開）：開始算進數字；[shouldRing] 為 true 時鈴鐺搖一下
  void release(String notificationId, {bool shouldRing = true}) {
    final Set<String> remainingIds = {...heldBackIds.value};
    remainingIds.remove(notificationId);
    heldBackIds.value = remainingIds;
    if (shouldRing) ring();
  }

  void releaseAll() {
    heldBackIds.value = <String>{};
  }

  void ring() => ringSignal.value++;
}
