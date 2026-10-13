import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  // 2026-10-14（3-H／M1）移除寫死的 3 則假通知；真實通知（行程提醒、拜訪紀錄整理完成）於第 4 階段實作
  NotificationService._internal();

  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void addNotification({
    required String senderName,
    required String title,
    required String content,
    required NotificationType type,
    String? targetCustomerId,
  }) {
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      profileId: 'demo-user',
      senderName: senderName,
      title: title,
      content: content,
      type: type,
      isRead: false,
      targetCustomerId: targetCustomerId,
      createdAt: DateTime.now(),
    );
    _notifications.insert(0, notif);
    notifyListeners();
  }
}
