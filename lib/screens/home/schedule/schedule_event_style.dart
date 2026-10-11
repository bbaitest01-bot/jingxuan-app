import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';

/// 日時間軸上一個行程的排版位置：排在第幾欄、這一群重疊的行程總共幾欄
class TimelineEventLayout {
  final ScheduleEvent event;
  final int colIndex;
  final int totalCols;
  TimelineEventLayout(this.event, this.colIndex, this.totalCols);
}

// 計算日時間軸上每個行程要排在第幾欄：時間重疊的行程並排顯示，不互相蓋住
List<TimelineEventLayout> computeTimelineLayouts(
    List<ScheduleEvent> events, DateTime dayStart, DateTime dayEnd) {
  if (events.isEmpty) return [];

  final dayEvents = events.where((e) {
    final DateTime effectiveEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
        ? e.endAt.subtract(const Duration(seconds: 1))
        : e.endAt;
    return !e.startAt.isAfter(dayEnd) && !effectiveEnd.isBefore(dayStart);
  }).toList();

  dayEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

  List<List<ScheduleEvent>> clusters = [];
  for (final event in dayEvents) {
    bool addedToCluster = false;
    for (final cluster in clusters) {
      bool overlapsAny = cluster.any((e) {
        final DateTime eEffEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
            ? e.endAt.subtract(const Duration(seconds: 1))
            : e.endAt;
        final DateTime eventEffEnd = (event.endAt.hour == 0 && event.endAt.minute == 0 && event.endAt.second == 0 && event.endAt.isAfter(event.startAt))
            ? event.endAt.subtract(const Duration(seconds: 1))
            : event.endAt;

        return event.startAt.isBefore(eEffEnd) && eventEffEnd.isAfter(e.startAt);
      });
      if (overlapsAny) {
        cluster.add(event);
        addedToCluster = true;
        break;
      }
    }
    if (!addedToCluster) {
      clusters.add([event]);
    }
  }

  List<TimelineEventLayout> layouts = [];

  for (final cluster in clusters) {
    List<DateTime> colEndTimes = [];
    List<int> eventCols = [];

    for (final event in cluster) {
      int assignedCol = -1;
      for (int c = 0; c < colEndTimes.length; c++) {
        if (!event.startAt.isBefore(colEndTimes[c])) {
          assignedCol = c;
          colEndTimes[c] = event.endAt;
          break;
        }
      }
      if (assignedCol == -1) {
        assignedCol = colEndTimes.length;
        colEndTimes.add(event.endAt);
      }
      eventCols.add(assignedCol);
    }

    final int numCols = colEndTimes.length;

    for (int i = 0; i < cluster.length; i++) {
      layouts.add(TimelineEventLayout(cluster[i], eventCols[i], numCols));
    }
  }

  return layouts;
}

// 行程類型的代表色（圓點、邊框、標籤文字）
Color scheduleEventTypeColor(String type, Color defaultColor) {
  switch (type) {
    case 'meeting':
      return Colors.orange;
    case 'visit':
    case 'customer_visit':
      return Colors.blue;
    case 'reminder':
    case 'follow_up':
      return Colors.purple;
    case 'general':
    case 'personal':
    default:
      return defaultColor;
  }
}

// 行程類型的卡片底色（深色／淺色模式各一套）
Color scheduleEventTypeBackgroundColor(String type, bool isDark) {
  switch (type) {
    case 'meeting':
      return isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.5) : const Color(0xFFFFEDD5);
    case 'visit':
    case 'customer_visit':
      return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFDBEAFE);
    case 'reminder':
    case 'follow_up':
      return isDark ? const Color(0xFF581C87).withValues(alpha: 0.5) : const Color(0xFFF3E8FF);
    case 'general':
    case 'personal':
    default:
      return isDark ? const Color(0xFF1F2937).withValues(alpha: 0.5) : const Color(0xFFF3F4F6);
  }
}

// 行程類型的中文名稱
String scheduleEventTypeLabel(String type) {
  switch (type) {
    case 'meeting':
      return '會議談判';
    case 'visit':
    case 'customer_visit':
      return '客戶拜訪';
    case 'reminder':
    case 'follow_up':
      return '跟進提醒';
    case 'general':
    case 'personal':
    default:
      return '個人行程';
  }
}

/// 打卡點樣式的行程（時間很短、格子太矮放不下卡片時使用）
class ScheduleBulletItem extends StatelessWidget {
  final String title;
  final String timeRange;
  final Color bulletColor;
  final bool isDark;

  const ScheduleBulletItem({
    super.key,
    required this.title,
    required this.timeRange,
    required this.bulletColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          // Glowing bullet point
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bulletColor.withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeRange,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 滿版卡片樣式的行程：標題、類型標籤、時間與地點
class ScheduleCardItem extends StatelessWidget {
  final String title;
  final String timeRange;
  final String location;
  final String tag;
  final Color cardColor;
  final Color borderColor;
  final Color accentColor;
  final bool isDark;

  const ScheduleCardItem({
    super.key,
    required this.title,
    required this.timeRange,
    required this.location,
    required this.tag,
    required this.cardColor,
    required this.borderColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final bool hasLocation = location.isNotEmpty && location != '未指定地點';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Row 1: 行程標題 (置頂顯示，絕不被壓迫或遮擋) + 標籤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            // Row 2: 時間區間與地點標籤
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: subTextColor),
                const SizedBox(width: 4),
                Text(
                  timeRange,
                  style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                if (hasLocation) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.location_on_outlined, size: 12, color: subTextColor),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(color: subTextColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
