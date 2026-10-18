import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';

/// 通知類型的代表色（鈴鐺清單、新通知卡片共用）：
/// 整理完成＝主題成功綠、整理失敗＝主題危險紅、行程提醒＝主題提醒色，明亮深色各自調過
Color notificationTypeColor(BuildContext context, NotificationType type) {
  switch (type) {
    case NotificationType.visitRecordReady:
      return context.appColors.ok;
    case NotificationType.visitRecordFailed:
      return Theme.of(context).colorScheme.error;
    case NotificationType.scheduleReminder:
      return context.appColors.warn;
  }
}
