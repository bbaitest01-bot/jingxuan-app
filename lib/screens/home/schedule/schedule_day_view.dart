import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import 'schedule_event_style.dart';
import 'schedule_page_state.dart';

/// 日時間軸視圖：00:00～23:00 的 24 小時格線，行程依時間排在格線上，重疊的行程並排。
class ScheduleDayView extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleDayView({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color gridColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color hourTextColor = isDark ? Colors.white30 : Colors.black45;

    final List<int> hours = List.generate(24, (index) => index); // 00:00 to 23:00 滿版 24 小時

    if (data.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data.events.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: primaryColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    '本日暫無排定行程',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊左側或下方按鈕新增第一個行程',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => actions.openEventEditor(null),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n('event_add_title')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final double totalGridHeight = hours.length * 60.0 + 80.0;

    final DateTime dayStart = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 0, 0);
    final DateTime dayEnd = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 23, 59, 59);

    final eventLayouts = computeTimelineLayouts(data.events, dayStart, dayEnd);

    final bool isToday = data.selectedDate.year == DateTime.now().year &&
        data.selectedDate.month == DateTime.now().month &&
        data.selectedDate.day == DateTime.now().day;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = (constraints.maxWidth - 70.0).clamp(100.0, 3000.0);

          return SizedBox(
            height: totalGridHeight,
            child: Stack(
              children: [
                // Timeline Base grid lines (00:00 至 23:00)
                Column(
                  children: hours.map((hour) {
                    final String hourLabel = hour.toString().padLeft(2, '0') + ':00';
                    return SizedBox(
                      height: 60,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              hourLabel,
                              style: TextStyle(
                                color: hourTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Divider(
                                color: gridColor,
                                thickness: 1,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // 今日紅點時間指示線 (Current Time Line)
                if (isToday)
                  Positioned(
                    top: (DateTime.now().hour + DateTime.now().minute / 60.0) * 60.0 + 8.0,
                    left: 45,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Colors.redAccent, thickness: 2, height: 2),
                        ),
                      ],
                    ),
                  ),

                // Render Dynamic Events Side-By-Side
                ...eventLayouts.map((layout) {
                  final event = layout.event;
                  final DateTime effectiveStart = event.startAt.isBefore(dayStart) ? dayStart : event.startAt;
                  final DateTime effectiveEnd = event.endAt.isAfter(dayEnd) ? dayEnd : event.endAt;

                  final double startHour = effectiveStart.hour + (effectiveStart.minute / 60.0);
                  final double endHour = effectiveEnd.hour + (effectiveEnd.minute / 60.0);

                  final double topOffset = startHour * 60.0 + 8.0;
                  final double durationHours = (endHour - startHour).clamp(0.5, 24.0);
                  final double cardHeight = durationHours * 60.0;

                  final double colWidth = availableWidth / layout.totalCols;
                  final double left = 60.0 + layout.colIndex * colWidth;
                  final double width = colWidth - 4.0;

                  final String timeRange = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';
                  final bool isShort = cardHeight <= 55;
                  final String displayTag = (event.tag != null && event.tag!.trim().isNotEmpty)
                      ? event.tag!.trim()
                      : scheduleEventTypeLabel(event.eventType);

                  return Positioned(
                    top: topOffset < 8.0 ? 8.0 : topOffset,
                    left: left < 60.0 ? 60.0 : left,
                    width: width < 30.0 ? 30.0 : width,
                    height: cardHeight < 40.0 ? 40.0 : cardHeight,
                    child: InkWell(
                      onTap: () => actions.openEventEditor(event),
                      borderRadius: BorderRadius.circular(8),
                      child: isShort
                          ? ScheduleBulletItem(
                              title: event.title,
                              timeRange: timeRange,
                              bulletColor: scheduleEventTypeColor(event.eventType, primaryColor),
                              isDark: isDark,
                            )
                          : ScheduleCardItem(
                              title: event.title,
                              timeRange: timeRange,
                              location: event.location ?? '未指定地點',
                              tag: displayTag,
                              cardColor: scheduleEventTypeBackgroundColor(event.eventType, isDark),
                              borderColor: scheduleEventTypeColor(event.eventType, primaryColor),
                              accentColor: scheduleEventTypeColor(event.eventType, primaryColor),
                              isDark: isDark,
                            ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
