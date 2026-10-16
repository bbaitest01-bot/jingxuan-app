import 'package:flutter/material.dart';

/// 通知分類（鈴鐺上方的分類列）。
/// 只放「已經有內容」的分類；行程提醒在 4-E3b 才會加進分類列（沛沛決定：展示時不放還沒有的功能）
enum NotificationCategory {
  visitRecord('拜訪紀錄'),
  schedule('行程提醒');

  final String label;
  const NotificationCategory(this.label);
}

/// 通知類型，對應資料表 notifications.type（4-E3a）
enum NotificationType {
  visitRecordReady('visit_record_ready', NotificationCategory.visitRecord, Icons.check_circle_rounded, Colors.green),
  visitRecordFailed('visit_record_failed', NotificationCategory.visitRecord, Icons.error_rounded, Colors.redAccent),
  scheduleReminder('schedule_reminder', NotificationCategory.schedule, Icons.alarm_rounded, Colors.orange);

  final String databaseValue;
  final NotificationCategory category;
  final IconData icon;
  final Color color;

  const NotificationType(this.databaseValue, this.category, this.icon, this.color);

  /// 資料庫的文字轉成類型；不認得的回傳 null（由呼叫的地方略過）
  static NotificationType? fromDatabaseValue(String? value) {
    for (final NotificationType type in NotificationType.values) {
      if (type.databaseValue == value) return type;
    }
    return null;
  }
}

/// 一則通知（資料表 notifications）
class AppNotification {
  final String id;
  final String profileId;
  final NotificationType type;
  final String title;
  final String content;
  final String? linkPath;
  final String? targetVisitRecordId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.linkPath,
    this.targetVisitRecordId,
  });

  /// 從資料庫的一列轉換；類型不認得時回傳 null
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final NotificationType? type = NotificationType.fromDatabaseValue(json['type'] as String?);
    if (type == null) return null;

    final String? createdAtText = json['created_at'] as String?;
    DateTime createdAt = DateTime.now();
    if (createdAtText != null) createdAt = DateTime.parse(createdAtText).toLocal();

    return AppNotification(
      id: json['id'] as String,
      profileId: json['profile_id'] as String? ?? '',
      type: type,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      linkPath: json['link_path'] as String?,
      targetVisitRecordId: json['target_visit_record_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      profileId: profileId,
      type: type,
      title: title,
      content: content,
      linkPath: linkPath,
      targetVisitRecordId: targetVisitRecordId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
