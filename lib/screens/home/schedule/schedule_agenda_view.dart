import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'schedule_page_state.dart';

/// 議程清單視圖：依日期列出接下來的行程。
class ScheduleAgendaView extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleAgendaView({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

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
                  Icon(Icons.event_available, size: 64, color: colors.ink3.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormat('yyyy/MM/dd', AppSettings.instance.language).format(data.selectedDate)} 起暫無未來排定行程',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊「新增行程」或語音助理排定新拜訪',
                    style: TextStyle(fontSize: 13, color: colors.ink3),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
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
            // 日期標題：淡主題色膠囊，日期用等寬字；今天多一個「今日」小標籤
            Container(
              margin: const EdgeInsets.only(top: 14, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 15,
                    color: colors.acc,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: AppTextStyles.mono(fontSize: 13, color: colors.acc),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.acc,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '今日',
                        style: TextStyle(color: colors.onAcc, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 議程卡片：白底、細框、不加陰影
            ...dayEvents.map((event) {
              final String timeRange = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors.line),
                ),
                child: InkWell(
                  onTap: () => actions.openEventEditor(event),
                  borderRadius: BorderRadius.circular(AppRadius.card),
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
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 時間
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 15, color: colors.ink3),
                                const SizedBox(width: 6),
                                Text(
                                  timeRange,
                                  style: AppTextStyles.mono(fontSize: 13, color: colors.ink2),
                                ),
                              ],
                            ),
                            // 地點 (若有)
                            if (event.location != null && event.location!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 15, color: colors.ink3),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      event.location!,
                                      style: TextStyle(fontSize: 13, color: colors.ink2),
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
                                  icon: Icon(Icons.alt_route, size: 20, color: colors.acc),
                                  tooltip: '路線導航',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => actions.openRoutePlanner(
                                    date: event.startAt,
                                    events: [event],
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, size: 20, color: colors.ink3),
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
