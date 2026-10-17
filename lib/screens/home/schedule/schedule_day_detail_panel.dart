import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'schedule_event_style.dart';
import 'schedule_page_state.dart';

/// 電腦版月網格右側的「當日詳情」面板：選定那一天的 24 小時時間軸。
class ScheduleDayDetailPanel extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleDayDetailPanel({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AppColors colors = context.appColors;
    final Color borderColor = colors.line;
    // 「現在時間」紅線用主題的危險色
    final Color nowLineColor = Theme.of(context).colorScheme.error;

    final dayEvents = data.events.where((e) {
      final DateTime dayStart = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 0, 0, 0);
      final DateTime dayEnd = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 23, 59, 59);
      final DateTime eEffEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
          ? e.endAt.subtract(const Duration(seconds: 1))
          : e.endAt;
      return !e.startAt.isAfter(dayEnd) && !eEffEnd.isBefore(dayStart);
    }).toList();

    dayEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

    final dateStr = DateFormat('MM/dd (EEE)', AppSettings.instance.language).format(data.selectedDate);

    final Color gridColor = colors.line;
    final Color hourTextColor = colors.ink3;
    final List<int> hours = List.generate(24, (index) => index); // 00:00 to 23:00 (24小時滿版時間軸)
    final double totalGridHeight = hours.length * 60.0 + 40.0;

    final DateTime dayStart = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 0, 0);
    final DateTime dayEnd = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 23, 59, 59);

    final eventLayouts = computeTimelineLayouts(dayEvents, dayStart, dayEnd);

    final bool isToday = data.selectedDate.year == DateTime.now().year &&
        data.selectedDate.month == DateTime.now().month &&
        data.selectedDate.day == DateTime.now().day;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // 面板 Header (08/04 (週二) 行程 (3) 與綠色 + 按鈕)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: colors.acc),
                    const SizedBox(width: 8),
                    // 面板標題用宋體
                    Text(
                      '$dateStr 行程 (${dayEvents.length})',
                      style: AppTextStyles.serif(fontSize: 16, color: colors.ink),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => actions.openEventEditor(null),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(context.l10n('event_add_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          // 面板 24 小時滿版刻度網格 (iPhone 日曆風格整點並排時間軸)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = (constraints.maxWidth - 55.0).clamp(100.0, 2000.0);

                  return SizedBox(
                    height: totalGridHeight,
                    child: Stack(
                      children: [
                        // 24 小時整點刻度橫線
                        Column(
                          children: hours.map((hour) {
                            final String hourLabel = hour.toString().padLeft(2, '0') + ':00';
                            return SizedBox(
                              height: 60,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 45,
                                    child: Text(
                                      hourLabel,
                                      style: AppTextStyles.mono(fontSize: 12, color: hourTextColor),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
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
                            top: (DateTime.now().hour + DateTime.now().minute / 60.0) * 60.0 + 6.0,
                            left: 40,
                            right: 0,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: nowLineColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: nowLineColor, thickness: 2, height: 2),
                                ),
                              ],
                            ),
                          ),

                        // 動態行程卡片 (並排計算 Side-By-Side)
                        ...eventLayouts.map((layout) {
                          final event = layout.event;
                          final DateTime effectiveStart = event.startAt.isBefore(dayStart) ? dayStart : event.startAt;
                          final DateTime effectiveEnd = event.endAt.isAfter(dayEnd) ? dayEnd : event.endAt;

                          final double startHour = effectiveStart.hour + (effectiveStart.minute / 60.0);
                          final double endHour = effectiveEnd.hour + (effectiveEnd.minute / 60.0);

                          final double topOffset = startHour * 60.0 + 6.0;
                          final double durationHours = (endHour - startHour).clamp(0.5, 24.0);
                          final double cardHeight = durationHours * 60.0;

                          final double colWidth = availableWidth / layout.totalCols;
                          final double left = 50.0 + layout.colIndex * colWidth;
                          final double width = colWidth - 4.0;

                          final String timeRange = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';
                          final bool isShort = cardHeight <= 55;
                          final String displayTag = (event.tag != null && event.tag!.trim().isNotEmpty)
                              ? event.tag!.trim()
                              : scheduleEventTypeLabel(event.eventType);

                          return Positioned(
                            top: topOffset < 6.0 ? 6.0 : topOffset,
                            left: left < 50.0 ? 50.0 : left,
                            width: width < 30.0 ? 30.0 : width,
                            height: cardHeight < 36.0 ? 36.0 : cardHeight,
                            child: InkWell(
                              onTap: () => actions.openEventEditor(event),
                              borderRadius: BorderRadius.circular(AppRadius.control),
                              child: isShort
                                  ? ScheduleBulletItem(
                                      title: event.title,
                                      timeRange: timeRange,
                                      bulletColor: scheduleEventTypeColor(context, event.eventType),
                                      isDark: isDark,
                                    )
                                  : ScheduleCardItem(
                                      title: event.title,
                                      timeRange: timeRange,
                                      location: event.location ?? '未指定地點',
                                      tag: displayTag,
                                      cardColor: scheduleEventTypeSoftColor(context, event.eventType),
                                      borderColor: scheduleEventTypeColor(context, event.eventType),
                                      accentColor: scheduleEventTypeColor(context, event.eventType),
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
            ),
          ),
        ],
      ),
    );
  }
}
