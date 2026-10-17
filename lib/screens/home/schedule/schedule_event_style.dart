import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import '../../../theme/app_theme.dart';

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

/// 行程類型的固定配色（「清爽組」，2026-10-18 沛沛選定）。
/// 四種類型都用固定顏色、不跟主題色變，才能保證彼此分得開；每種有代表色（實心）與淡底色，明亮、深色各一套。
/// 實心色上的字用 `onAcc`：明亮模式白字，深色模式代表色比較亮，改用深色字。
class ScheduleEventPalette {
  // 客戶拜訪：藍
  static const Color visitLight = Color(0xFF2F6DB5);
  static const Color visitLightSoft = Color(0xFFE4EDF8);
  static const Color visitDark = Color(0xFF7FB0E8);
  static const Color visitDarkSoft = Color(0xFF1A2A3D);
  // 會議談判：青綠
  static const Color meetingLight = Color(0xFF1A7A6C);
  static const Color meetingLightSoft = Color(0xFFE0F0EC);
  static const Color meetingDark = Color(0xFF6CC3B3);
  static const Color meetingDarkSoft = Color(0xFF142D29);
  // 跟進提醒：橘
  static const Color reminderLight = Color(0xFFA85A12);
  static const Color reminderLightSoft = Color(0xFFF6E8D8);
  static const Color reminderDark = Color(0xFFE8A35E);
  static const Color reminderDarkSoft = Color(0xFF33251A);
  // 個人行程：灰
  static const Color personalLight = Color(0xFF6B717C);
  static const Color personalLightSoft = Color(0xFFECEDEF);
  static const Color personalDark = Color(0xFFA0A6AF);
  static const Color personalDarkSoft = Color(0xFF23272D);
}

// 把資料庫裡的類型代碼歸成四類：visit、meeting、reminder、personal
String _scheduleEventCategory(String type) {
  switch (type) {
    case 'meeting':
      return 'meeting';
    case 'visit':
    case 'customer_visit':
      return 'visit';
    case 'reminder':
    case 'follow_up':
      return 'reminder';
    default:
      return 'personal';
  }
}

// 行程類型的代表色（月網格實心色條、圓點、卡片框線與標籤字）
Color scheduleEventTypeColor(BuildContext context, String type) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  switch (_scheduleEventCategory(type)) {
    case 'visit':
      return isDark ? ScheduleEventPalette.visitDark : ScheduleEventPalette.visitLight;
    case 'meeting':
      return isDark ? ScheduleEventPalette.meetingDark : ScheduleEventPalette.meetingLight;
    case 'reminder':
      return isDark ? ScheduleEventPalette.reminderDark : ScheduleEventPalette.reminderLight;
    default:
      return isDark ? ScheduleEventPalette.personalDark : ScheduleEventPalette.personalLight;
  }
}

// 行程類型的淡底色（日時間軸卡片底色），和代表色成對
Color scheduleEventTypeSoftColor(BuildContext context, String type) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  switch (_scheduleEventCategory(type)) {
    case 'visit':
      return isDark ? ScheduleEventPalette.visitDarkSoft : ScheduleEventPalette.visitLightSoft;
    case 'meeting':
      return isDark ? ScheduleEventPalette.meetingDarkSoft : ScheduleEventPalette.meetingLightSoft;
    case 'reminder':
      return isDark ? ScheduleEventPalette.reminderDarkSoft : ScheduleEventPalette.reminderLightSoft;
    default:
      return isDark ? ScheduleEventPalette.personalDarkSoft : ScheduleEventPalette.personalLightSoft;
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
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.line, width: 1),
      ),
      child: Row(
        children: [
          // 類型色小圓點（新風格不加發光）
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeRange,
            style: AppTextStyles.mono(fontSize: 12, color: colors.ink3),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.ink,
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
    final AppColors colors = context.appColors;
    final Color textColor = colors.ink;
    final Color subTextColor = colors.ink2;
    final bool hasLocation = location.isNotEmpty && location != '未指定地點';

    // 淡類型色底＋同色細框，不加陰影
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: borderColor.withValues(alpha: 0.45), width: 1),
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
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
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
                  style: AppTextStyles.mono(fontSize: 11, color: subTextColor),
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
