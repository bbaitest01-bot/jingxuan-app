import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'notification_type_color.dart';
import '../theme/app_theme.dart';

/// 鈴鐺打開的通知清單（4-E3a，問題 M2、M4）：
/// 分類列只放有內容的分類；點一則 → 標為已讀 → 前往該則的網址（例如那篇拜訪紀錄）
class NotificationCenterPopover extends StatefulWidget {
  const NotificationCenterPopover({super.key});

  // 分類列顯示哪些分類；行程提醒在 4-E3b 做好後再加入
  static const List<NotificationCategory> visibleCategories = [NotificationCategory.visitRecord];

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
          child: const NotificationCenterPopover(),
        ),
      ),
    );
  }

  @override
  State<NotificationCenterPopover> createState() => _NotificationCenterPopoverState();
}

class _NotificationCenterPopoverState extends State<NotificationCenterPopover> {
  final NotificationService _service = NotificationService();
  // null 代表「全部」
  NotificationCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // 打開時重讀一次，即時推送斷線時也不會漏掉
    _service.loadNotifications();
  }

  List<AppNotification> _filteredNotifications() {
    final List<AppNotification> allNotifications = _service.notifications;
    if (_selectedCategory == null) return allNotifications;
    return allNotifications.where((AppNotification item) => item.type.category == _selectedCategory).toList();
  }

  // 點一則通知：標為已讀、關掉清單、前往該則的網址
  void _openNotification(AppNotification notification) {
    _service.markAsRead(notification.id);
    final String? linkPath = notification.linkPath;
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (linkPath != null && linkPath.isNotEmpty) router.go(linkPath);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (BuildContext context, _) {
        final List<AppNotification> notifications = _filteredNotifications();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NotificationHeader(
              unreadCount: _service.unreadCount,
              onMarkAllRead: _service.markAllAsRead,
              onClose: () => Navigator.of(context).pop(),
            ),
            _buildCategoryBar(),
            const Divider(height: 1),
            Flexible(child: _buildList(notifications)),
          ],
        );
      },
    );
  }

  // 分類列：手機寬度可以左右滑
  Widget _buildCategoryBar() {
    final List<Widget> chips = [_buildCategoryChip('全部', null)];
    for (final NotificationCategory category in NotificationCenterPopover.visibleCategories) {
      chips.add(_buildCategoryChip(category.label, category));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: chips),
    );
  }

  Widget _buildCategoryChip(String label, NotificationCategory? category) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedCategory == category,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }

  Widget _buildList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 48, color: context.appColors.ink3),
            const SizedBox(height: 12),
            Text('目前沒有通知', style: TextStyle(color: context.appColors.ink3)),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final AppNotification notification = notifications[index];
        return NotificationCard(notification: notification, onTap: () => _openNotification(notification));
      },
    );
  }
}

/// 清單上方：標題、未讀數、全部已讀、關閉
class _NotificationHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClose;

  const _NotificationHeader({required this.unreadCount, required this.onMarkAllRead, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: primaryColor),
          const SizedBox(width: 8),
          const Text('通知', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (unreadCount > 0) Text('$unreadCount 則未讀', style: TextStyle(fontSize: 12, color: primaryColor)),
          const Spacer(),
          TextButton(
            onPressed: unreadCount > 0 ? onMarkAllRead : null,
            child: const Text('全部已讀'),
          ),
          IconButton(
            tooltip: '關閉',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// 一則通知：完成綠勾、失敗紅色驚嘆號；未讀的粗體＋小圓點
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationCard({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color typeColor = notificationTypeColor(context, notification.type);
    final bool isUnread = !notification.isRead;
    Color borderColor = context.appColors.line;
    if (isUnread) borderColor = typeColor.withValues(alpha: 0.6);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notification.type.icon, color: typeColor, size: 22),
            const SizedBox(width: 10),
            Expanded(child: _buildTexts(context, isUnread)),
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(radius: 4, backgroundColor: typeColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTexts(BuildContext context, bool isUnread) {
    FontWeight titleWeight = FontWeight.normal;
    if (isUnread) titleWeight = FontWeight.bold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(notification.title, style: TextStyle(fontSize: 14, fontWeight: titleWeight)),
        const SizedBox(height: 4),
        Text(notification.content, style: const TextStyle(fontSize: 13, height: 1.4)),
        const SizedBox(height: 4),
        Text(formatNotificationTime(notification.createdAt, DateTime.now()), style: TextStyle(fontSize: 11, color: context.appColors.ink3)),
      ],
    );
  }
}

/// 「剛剛／5 分鐘前／3 小時前／2 天前」
String formatNotificationTime(DateTime createdAt, DateTime now) {
  final Duration difference = now.difference(createdAt);
  if (difference.inMinutes < 1) return '剛剛';
  if (difference.inMinutes < 60) return '${difference.inMinutes} 分鐘前';
  if (difference.inHours < 24) return '${difference.inHours} 小時前';
  return '${difference.inDays} 天前';
}
