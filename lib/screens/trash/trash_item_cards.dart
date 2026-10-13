import 'package:flutter/material.dart';
import '../../models/schedule_event.dart';

/// 垃圾桶保留天數
const int trashKeepDays = 30;

/// 放進垃圾桶後還剩幾天會被自動清除
int trashDaysLeft(DateTime deletedAt) {
  final int passedDays = DateTime.now().difference(deletedAt).inDays;
  final int remainingDays = trashKeepDays - passedDays;
  if (remainingDays < 0) return 0;
  return remainingDays;
}

/// 卡片共用的顏色
class TrashCardColors {
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final Color primaryColor;

  const TrashCardColors({
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.primaryColor,
  });
}

/// 垃圾桶裡的一張卡片（客戶或行程共用外框）：上排類型與剩餘天數、中間內容、下排「永久刪除／還原」
class TrashItemCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String typeLabel;
  final Color typeColor;
  final int daysLeft;
  final String detailText;
  final String restoreLabel;
  final bool highlightBorder;
  final TrashCardColors colors;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const TrashItemCard({
    super.key,
    required this.leading,
    required this.title,
    required this.typeLabel,
    required this.typeColor,
    required this.daysLeft,
    required this.detailText,
    required this.restoreLabel,
    required this.colors,
    required this.onRestore,
    required this.onDeleteForever,
    this.highlightBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBorder = colors.borderColor;
    if (highlightBorder) cardBorder = typeColor.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: highlightBorder ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(child: _buildTitleAndType()),
                TrashDaysLeftBadge(daysLeft: daysLeft),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                detailText,
                style: TextStyle(fontSize: 11, color: colors.subTextColor, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 12),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleAndType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            typeLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: onDeleteForever,
          icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Colors.redAccent),
          label: const Text('永久刪除', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            side: const BorderSide(color: Colors.redAccent, width: 0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore_from_trash_rounded, size: 14),
          label: Text(restoreLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

/// 「剩 N 天」小標籤：7 天內紅色、15 天內黃色，其餘綠色
class TrashDaysLeftBadge extends StatelessWidget {
  final int daysLeft;

  const TrashDaysLeftBadge({super.key, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    Color badgeColor = Colors.green;
    if (daysLeft <= 7) {
      badgeColor = Colors.redAccent;
    } else if (daysLeft <= 15) {
      badgeColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        '剩 $daysLeft 天',
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 已刪除的客戶（正式客戶或語音草稿）
class DeletedCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final TrashCardColors colors;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const DeletedCustomerCard({
    super.key,
    required this.customer,
    required this.colors,
    required this.onRestore,
    required this.onDeleteForever,
  });

  static bool isDraftCustomer(Map<String, dynamic> customer) {
    return customer['status'] == 'draft' || customer['status'] == 'discarded_draft';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDraft = isDraftCustomer(customer);
    const Color draftColor = Color(0xFFF59E0B);
    const Color customerColor = Color(0xFF0EA5E9);
    final String name = customer['name'] as String? ?? '';
    final DateTime deletedAt = DateTime.tryParse(customer['deleted_at']?.toString() ?? '') ?? DateTime.now();

    // 草稿顯示速記摘要；正式客戶顯示電話與標籤
    String detailText;
    final String notes = customer['notes']?.toString() ?? '';
    if (isDraft) {
      detailText = notes.isNotEmpty ? '速記摘要: $notes' : '無語音錄音摘要';
    } else {
      final List<dynamic> tags = customer['tags'] as List<dynamic>? ?? [];
      detailText = '聯絡電話: ${customer['phone'] ?? '未填寫'} · 標籤: ${tags.join(', ')}';
    }

    return TrashItemCard(
      leading: _buildAvatar(name, isDraft ? draftColor : colors.primaryColor),
      title: name,
      typeLabel: isDraft ? '🟡 語音速記草稿' : '👥 正式客戶',
      typeColor: isDraft ? draftColor : customerColor,
      highlightBorder: isDraft,
      daysLeft: trashDaysLeft(deletedAt),
      detailText: detailText,
      restoreLabel: isDraft ? '還原草稿' : '還原客戶',
      colors: colors,
      onRestore: onRestore,
      onDeleteForever: onDeleteForever,
    );
  }

  Widget _buildAvatar(String name, Color accentColor) {
    final String avatarUrl = customer['avatar_url'] as String? ?? '';
    ImageProvider? avatarProvider;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      avatarProvider = NetworkImage(avatarUrl);
    } else if (avatarUrl.isNotEmpty) {
      avatarProvider = AssetImage(avatarUrl);
    }

    Widget? initialText;
    if (avatarProvider == null) {
      final String firstLetter = name.isNotEmpty ? name.substring(0, 1) : '?';
      initialText = Text(
        firstLetter,
        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: accentColor.withValues(alpha: 0.12),
      backgroundImage: avatarProvider,
      child: initialText,
    );
  }
}

/// 已刪除的行程
class DeletedScheduleCard extends StatelessWidget {
  final ScheduleEvent event;
  final TrashCardColors colors;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const DeletedScheduleCard({
    super.key,
    required this.event,
    required this.colors,
    required this.onRestore,
    required this.onDeleteForever,
  });

  static const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  // 例：2026/10/15 (週四) 14:00–15:00
  static String formatEventTime(ScheduleEvent event) {
    final DateTime start = event.startAt;
    final DateTime end = event.endAt;
    final String date = '${start.year}/${_twoDigits(start.month)}/${_twoDigits(start.day)}';
    final String weekday = _weekdayNames[start.weekday - 1];
    final String startTime = '${_twoDigits(start.hour)}:${_twoDigits(start.minute)}';
    final String endTime = '${_twoDigits(end.hour)}:${_twoDigits(end.minute)}';
    return '$date (週$weekday) $startTime–$endTime';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    const Color scheduleColor = Color(0xFF8B5CF6);
    final DateTime deletedAt = event.deletedAt ?? DateTime.now();

    String detailText = '時間: ${formatEventTime(event)}';
    final String location = event.location ?? '';
    if (location.isNotEmpty) detailText = '$detailText · 地點: $location';

    return TrashItemCard(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: scheduleColor.withValues(alpha: 0.12),
        child: const Icon(Icons.event_rounded, color: scheduleColor, size: 20),
      ),
      title: event.title,
      typeLabel: '📅 行程',
      typeColor: scheduleColor,
      daysLeft: trashDaysLeft(deletedAt),
      detailText: detailText,
      restoreLabel: '還原行程',
      colors: colors,
      onRestore: onRestore,
      onDeleteForever: onDeleteForever,
    );
  }
}
