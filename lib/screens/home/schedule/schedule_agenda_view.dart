import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import 'schedule_page_state.dart';

/// 議程清單視圖：依日期列出接下來的行程。
class ScheduleAgendaView extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleAgendaView({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;

    if (data.isLoading && data.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 1. 過濾：不論點到哪一天，一律不顯示已經過去 (結束時間早於目前實時間 now) 的歷史事件
    final DateTime now = DateTime.now();
    final upcomingEvents = data.events.where((e) {
      return !e.endAt.isBefore(now);
    }).toList();

    upcomingEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

    if (upcomingEvents.isEmpty) {
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
                    '${DateFormat('yyyy/MM/dd', AppSettings.instance.language).format(data.selectedDate)} 起暫無未來排定行程',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊「新增行程」或語音助理排定新拜訪',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => actions.openEventEditor(null),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n('event_add_title')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 2. 按日期 (yyyy/MM/dd) 進行群組化
    final Map<String, List<ScheduleEvent>> groupedEvents = {};
    for (final event in upcomingEvents) {
      final key = DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(event.startAt);
      groupedEvents.putIfAbsent(key, () => []).add(event);
    }

    final dateKeys = groupedEvents.keys.toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateStr = dateKeys[index];
        final dayEvents = groupedEvents[dateStr]!;
        final DateTime firstEventDate = dayEvents.first.startAt;
        final bool isToday = firstEventDate.year == DateTime.now().year &&
            firstEventDate.month == DateTime.now().month &&
            firstEventDate.day == DateTime.now().day;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期 Header 標題膠囊 (完全對齊截圖 1 的紫光膠囊風格)
            Container(
              margin: const EdgeInsets.only(top: 14, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E1065).withValues(alpha: 0.6) : primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 15,
                    color: isDark ? const Color(0xFFA78BFA) : primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFA78BFA) : primaryColor,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '今日',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 議程卡片列表 (完全對齊截圖 1 的深色大卡片風格)
            ...dayEvents.map((event) {
              final String timeRange = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: InkWell(
                  onTap: () => actions.openEventEditor(event),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 標題
                            Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 時間
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 15, color: isDark ? Colors.white54 : Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  timeRange,
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ],
                            ),
                            // 地點 (若有)
                            if (event.location != null && event.location!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 15, color: const Color(0xFFEF4444)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      event.location!,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        // 右下角按鈕組 (對齊截圖 1 的方向指引與編輯圖示)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (event.location != null && event.location!.trim().isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.alt_route, size: 20, color: Color(0xFF3B82F6)),
                                  tooltip: '路線導航',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => actions.openRoutePlanner(
                                    date: event.startAt,
                                    events: [event],
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                                tooltip: '編輯行程',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => actions.openEventEditor(event),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
