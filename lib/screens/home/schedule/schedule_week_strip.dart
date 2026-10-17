import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../theme/app_theme.dart';
import 'schedule_page_state.dart';

/// 手機版今日行程上方的「週曆列」：顯示月份標題與這一週七天，可切換上一週／下一週。
class ScheduleWeekStrip extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleWeekStrip({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color borderColor = colors.line;
    final Color textColor = colors.ink;
    final Color subTextColor = colors.ink3;

    final List<DateTime> weekDates = _weekDatesOf(data.selectedDate);
    final String localeStr = AppSettings.instance.language;
    final String monthString = DateFormat.yMMMM(localeStr).format(data.selectedDate);

    // Get narrow weekdays from date symbols (Sun, Mon, Tue...)
    final List<String> narrowWeekdays = DateFormat.E(localeStr).dateSymbols.NARROWWEEKDAYS;
    // Map to Mon-Sun
    final List<String> weekdays = [
      narrowWeekdays[1], // Mon
      narrowWeekdays[2], // Tue
      narrowWeekdays[3], // Wed
      narrowWeekdays[4], // Thu
      narrowWeekdays[5], // Fri
      narrowWeekdays[6], // Sat
      narrowWeekdays[0], // Sun
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Title
          GestureDetector(
            onTap: () => actions.pickDate(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 年月是這一區的標題，用宋體
                  Text(
                    monthString,
                    style: AppTextStyles.serif(fontSize: 18, color: textColor),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_drop_down, color: colors.acc, size: 24),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Weekly Row
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: colors.ink2),
                tooltip: '上一週',
                onPressed: () {
                  actions.selectDateAndReload(data.selectedDate.subtract(const Duration(days: 7)));
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final DateTime date = weekDates[index];
                    final bool isSelected = date.year == data.selectedDate.year &&
                        date.month == data.selectedDate.month &&
                        date.day == data.selectedDate.day;
                    
                    final bool isToday = date.day == DateTime.now().day &&
                        date.month == DateTime.now().month &&
                        date.year == DateTime.now().year;

                    // 選中：主題色底、onAcc 字；今天（沒選中）：淡主題色底＋主題色框
                    Color dayBackground = Colors.transparent;
                    Color dayBorder = Colors.transparent;
                    Color weekdayColor = subTextColor;
                    Color dayNumberColor = textColor;
                    if (isToday) {
                      dayBackground = colors.accSoft;
                      dayBorder = colors.acc;
                    }
                    if (isSelected) {
                      dayBackground = colors.acc;
                      dayBorder = Colors.transparent;
                      weekdayColor = colors.onAcc;
                      dayNumberColor = colors.onAcc;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          actions.selectDateAndReload(date);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: dayBackground,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: dayBorder, width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekdays[index],
                                style: TextStyle(
                                  color: weekdayColor,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${date.day}',
                                style: AppTextStyles.mono(fontSize: 16, color: dayNumberColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: colors.ink2),
                tooltip: '下一週',
                onPressed: () {
                  actions.selectDateAndReload(data.selectedDate.add(const Duration(days: 7)));
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  // 找出某一天所在那一週（週一到週日）的七個日期
  List<DateTime> _weekDatesOf(DateTime date) {
    final int daysFromMonday = date.weekday - 1;
    final DateTime monday = date.subtract(Duration(days: daysFromMonday));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }
}
