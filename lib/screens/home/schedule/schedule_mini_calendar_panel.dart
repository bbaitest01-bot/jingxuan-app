import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import 'schedule_page_state.dart';

/// 電腦版日時間軸右側的「小月曆」面板：可點選日期、新增行程，下方有今日摘要。
class ScheduleMiniCalendarPanel extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleMiniCalendarPanel({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;

    final dayEventsCount = data.events.where((e) {
      final DateTime dayStart = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 0, 0, 0);
      final DateTime dayEnd = DateTime(data.selectedDate.year, data.selectedDate.month, data.selectedDate.day, 23, 59, 59);
      final DateTime eEffEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
          ? e.endAt.subtract(const Duration(seconds: 1))
          : e.endAt;
      return !e.startAt.isAfter(dayEnd) && !eEffEnd.isBefore(dayStart);
    }).length;

    final dateStr = DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(data.selectedDate);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.grey.shade50,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 面板 Header
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, size: 20, color: isDark ? const Color(0xFFA78BFA) : primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '日曆快速導航',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: actions.reload,
                    tooltip: '重新整理',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 小月曆 Picker 卡片 (點選即時切換日時間軸)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CalendarDatePicker(
                  key: ValueKey('mini-picker-${data.selectedDate.year}-${data.selectedDate.month}-${data.selectedDate.day}'),
                  initialDate: data.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  onDateChanged: (newDate) {
                    actions.selectDateAndReload(newDate);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 選定日期資訊與新增行程按鈕
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$dayEventsCount 筆行程',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => actions.openEventEditor(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.l10n('event_add_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 本日概覽統計卡片
            _buildTodaySummaryCard(context, isDark, borderColor, primaryColor),
          ],
        ),
      ),
    );
  }

  // 今日摘要卡：總行程數、已完成數等統計
  Widget _buildTodaySummaryCard(BuildContext context, bool isDark, Color borderColor, Color primaryColor) {
    final totalCount = data.events.length;
    final completedCount = data.events.where((e) => e.isCompleted).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Text(context.l10n('today_summary'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(context.l10n('stat_total'), '$totalCount', isDark),
                _buildSummaryStat(context.l10n('stat_completed'), '$completedCount', isDark),
                _buildSummaryStat(context.l10n('stat_pending'), '${totalCount - completedCount}', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
      ],
    );
  }
}
