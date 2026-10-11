import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import '../../../services/app_settings.dart';
import 'schedule_event_style.dart';
import 'schedule_page_state.dart';

/// 月網格視圖：一次看整個月，每格顯示當天的行程。
class ScheduleMonthView extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleMonthView({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;

    if (data.isLoading && data.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final DateTime firstDayOfMonth = DateTime(data.selectedDate.year, data.selectedDate.month, 1);
    final int leadingOffset = firstDayOfMonth.weekday % 7; // Sunday = 0
    final DateTime gridStartDate = firstDayOfMonth.subtract(Duration(days: leadingOffset));

    final bool isEn = AppSettings.instance.language == 'en_US';
    final List<String> weekHeaderLabels = isEn
        ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : ['日', '一', '二', '三', '四', '五', '六'];

    List<List<DateTime>> weekGrid = [];
    DateTime currDate = gridStartDate;

    while (true) {
      List<DateTime> week = [];
      for (int i = 0; i < 7; i++) {
        week.add(currDate);
        currDate = currDate.add(const Duration(days: 1));
      }
      weekGrid.add(week);
      if (currDate.month != data.selectedDate.month && weekGrid.length >= 5) {
        break;
      }
    }

    return Column(
      children: [
        // Weekday Header Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: weekHeaderLabels.map((label) {
              final bool isWeekend = label == '日' || label == '六' || label == 'Sun' || label == 'Sat';
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isWeekend ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Month Grid Weeks List
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: weekGrid.length,
            itemBuilder: (context, weekIdx) {
              final weekDays = weekGrid[weekIdx];
              final DateTime weekStart = DateTime(weekDays.first.year, weekDays.first.month, weekDays.first.day, 0, 0, 0);
              final DateTime weekEnd = DateTime(weekDays.last.year, weekDays.last.month, weekDays.last.day, 23, 59, 59);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 110,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double colWidth = constraints.maxWidth / 7.0;

                    // Filter events overlapping this 7-day week
                    final List<ScheduleEvent> weekEvents = data.events.where((e) {
                      final DateTime effectiveEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
                          ? e.endAt.subtract(const Duration(seconds: 1))
                          : e.endAt;

                      return !e.startAt.isAfter(weekEnd) && !effectiveEnd.isBefore(weekStart);
                    }).toList();

                    return Stack(
                      children: [
                        // Base 7 Grid Cells (Background)
                        Row(
                          children: List.generate(7, (colIdx) {
                            final DateTime cellDate = weekDays[colIdx];
                            final bool isCurrentMonthDay = cellDate.month == data.selectedDate.month;
                            final bool isToday = cellDate.year == DateTime.now().year &&
                                cellDate.month == DateTime.now().month &&
                                cellDate.day == DateTime.now().day;
                            final bool isSelected = cellDate.year == data.selectedDate.year &&
                                cellDate.month == data.selectedDate.month &&
                                cellDate.day == data.selectedDate.day;

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  final bool sameMonth = cellDate.month == data.selectedDate.month && cellDate.year == data.selectedDate.year;
                                  // 同一個月的資料已經讀過，只換日期；換到別的月份才重新讀取
                                  if (sameMonth) {
                                    actions.selectDate(cellDate);
                                  } else {
                                    actions.selectDateAndReload(cellDate);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.08)
                                        : (isCurrentMonthDay
                                            ? (isDark ? const Color(0xFF161B22) : Colors.white)
                                            : (isDark ? const Color(0xFF0D1117).withValues(alpha: 0.3) : Colors.grey.shade50)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : isToday
                                              ? primaryColor.withValues(alpha: 0.5)
                                              : (isCurrentMonthDay ? borderColor : borderColor.withValues(alpha: 0.3)),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: isToday
                                                ? BoxDecoration(
                                                    color: primaryColor,
                                                    shape: BoxShape.circle,
                                                  )
                                                : null,
                                            child: Text(
                                              '${cellDate.day}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isToday
                                                    ? Colors.white
                                                    : (isSelected
                                                        ? primaryColor
                                                        : (isCurrentMonthDay
                                                            ? (isDark ? Colors.white70 : Colors.black87)
                                                            : (isDark ? Colors.white30 : Colors.black38))),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        // Event Banners Overlay (Continuous Horizontal Banners Across Multi-Days with Intelligent Slot Allocation)
                        ...() {
                          final List<Widget> bannerWidgets = [];
                          final List<List<bool>> occupiedSlots = List.generate(4, (_) => List.filled(7, false));

                          for (final event in weekEvents) {
                            final DateTime effectiveEnd = (event.endAt.hour == 0 && event.endAt.minute == 0 && event.endAt.second == 0 && event.endAt.isAfter(event.startAt))
                                ? event.endAt.subtract(const Duration(seconds: 1))
                                : event.endAt;

                            final DateTime eventStartDate = DateTime(event.startAt.year, event.startAt.month, event.startAt.day);
                            final DateTime eventEndDate = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);

                            int startCol = -1;
                            int endCol = -1;

                            for (int c = 0; c < 7; c++) {
                              final date = DateTime(weekDays[c].year, weekDays[c].month, weekDays[c].day);
                              final bool overlaps = !date.isBefore(eventStartDate) && !date.isAfter(eventEndDate);

                              if (overlaps) {
                                if (startCol == -1) startCol = c;
                                endCol = c;
                              }
                            }

                            if (startCol == -1 || endCol == -1) continue;

                            int assignedSlot = -1;
                            for (int slot = 0; slot < 3; slot++) {
                              bool isFree = true;
                              for (int c = startCol; c <= endCol; c++) {
                                if (occupiedSlots[slot][c]) {
                                  isFree = false;
                                  break;
                                }
                              }
                              if (isFree) {
                                assignedSlot = slot;
                                break;
                              }
                            }

                            if (assignedSlot == -1) continue;

                            for (int c = startCol; c <= endCol; c++) {
                              occupiedSlots[assignedSlot][c] = true;
                            }

                            final double left = startCol * colWidth + 4.0;
                            final double width = (endCol - startCol + 1) * colWidth - 8.0;
                            final double top = 30.0 + assignedSlot * 24.0;

                            final String displayTag = (event.tag != null && event.tag!.trim().isNotEmpty)
                                ? event.tag!.trim()
                                : event.title;

                            final Color bannerBg = scheduleEventTypeColor(event.eventType, primaryColor);

                            bannerWidgets.add(
                              Positioned(
                                top: top,
                                left: left,
                                width: width < 10.0 ? 10.0 : width,
                                height: 22.0,
                                child: InkWell(
                                  onTap: () => actions.openEventEditor(event),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: bannerBg.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: bannerBg.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      displayTag,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return bannerWidgets;
                        }(),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
