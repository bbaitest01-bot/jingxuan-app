import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show isOfflineMode;
import '../models/app_notification.dart';

/// 通知中心（4-E3a，問題 M3、M4）：讀寫資料表 notifications。
/// - 通知只由資料庫產生（拜訪紀錄整理完成／失敗時的觸發器），App 只負責讀、標已讀
/// - 登入後 [start]：讀一次清單，並開啟即時推送；新通知一進來就加到清單並從 [arrivals] 送出
/// - 離線預覽模式不連資料庫，清單一直是空的
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 鈴鐺最多顯示幾則（資料庫只保留 30 天）
  static const int maxListLength = 50;

  final List<AppNotification> _notifications = [];
  final StreamController<AppNotification> _arrivalController = StreamController<AppNotification>.broadcast();
  RealtimeChannel? _channel;
  String? _startedUserId;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount {
    int count = 0;
    for (final AppNotification notification in _notifications) {
      if (!notification.isRead) count++;
    }
    return count;
  }

  /// 即時推送收到的新通知（用來在畫面上跳出提示）
  Stream<AppNotification> get arrivals => _arrivalController.stream;

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId {
    if (isOfflineMode) return null;
    return _supabase.auth.currentUser?.id;
  }

  /// 登入後呼叫：讀清單並開始接收即時推送（同一個帳號重複呼叫不會重開）
  Future<void> start() async {
    final String? userId = _currentUserId;
    if (userId == null || userId == _startedUserId) return;
    await stop();
    _startedUserId = userId;
    _listenForNewNotifications(userId);
    await loadNotifications();
  }

  /// 離開主畫面（登出）時呼叫：關閉即時推送、清空清單。
  /// 這時畫面正在關閉，所以不通知畫面更新；下次 [start] 讀完清單才會更新
  Future<void> stop() async {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    _startedUserId = null;
    _notifications.clear();
    if (channel != null) {
      try {
        await _supabase.removeChannel(channel);
      } catch (error) {
        debugPrint('[NotificationService] 關閉即時推送失敗：$error');
      }
    }
  }

  /// 重新讀自己的通知（新到舊）；打開鈴鐺時也會呼叫，避免即時推送斷線時漏掉
  Future<void> loadNotifications() async {
    final String? userId = _currentUserId;
    if (userId == null) return;
    try {
      final List<dynamic> rows = await _supabase
          .from('notifications')
          .select()
          .eq('profile_id', userId)
          .order('created_at', ascending: false)
          .limit(maxListLength);

      _notifications.clear();
      for (final dynamic row in rows) {
        final AppNotification? notification = AppNotification.fromJson(row as Map<String, dynamic>);
        if (notification != null) _notifications.add(notification);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('[NotificationService] 讀取通知失敗：$error');
    }
  }

  // 即時推送：資料庫新增「自己的」通知時，Supabase 會從網頁開著的連線直接送過來（受 RLS 限制）
  void _listenForNewNotifications(String userId) {
    try {
      _channel = _supabase
          .channel('notifications-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'profile_id', value: userId),
            callback: (PostgresChangePayload payload) => receiveNotificationRow(payload.newRecord),
          )
          .subscribe();
    } catch (error) {
      debugPrint('[NotificationService] 開啟即時推送失敗：$error');
    }
  }

  /// 收到一則新通知（即時推送呼叫；測試也用這個）
  void receiveNotificationRow(Map<String, dynamic> row) {
    final AppNotification? notification = AppNotification.fromJson(row);
    if (notification == null) return;
    // 已經在清單裡（例如剛好重新讀過）就不重複加
    for (final AppNotification existing in _notifications) {
      if (existing.id == notification.id) return;
    }
    _notifications.insert(0, notification);
    if (_notifications.length > maxListLength) _notifications.removeLast();
    notifyListeners();
    _arrivalController.add(notification);
  }

  /// 標為已讀：畫面先變，再寫回資料庫
  Future<void> markAsRead(String notificationId) async {
    final int index = _notifications.indexWhere((AppNotification item) => item.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();

    final String? userId = _currentUserId;
    if (userId == null) return;
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId).eq('profile_id', userId);
    } catch (error) {
      debugPrint('[NotificationService] 標為已讀失敗：$error');
    }
  }

  /// 全部標為已讀
  Future<void> markAllAsRead() async {
    bool hasChanged = false;
    for (int index = 0; index < _notifications.length; index++) {
      if (_notifications[index].isRead) continue;
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      hasChanged = true;
    }
    if (!hasChanged) return;
    notifyListeners();

    final String? userId = _currentUserId;
    if (userId == null) return;
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('profile_id', userId).eq('is_read', false);
    } catch (error) {
      debugPrint('[NotificationService] 全部標為已讀失敗：$error');
    }
  }

  /// 測試用：清空清單
  @visibleForTesting
  void clearForTest() {
    _notifications.clear();
    _startedUserId = null;
    notifyListeners();
  }
}
