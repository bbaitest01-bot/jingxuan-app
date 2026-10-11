import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import 'schedule_page_state.dart';

/// 今日行程最上方的工具列：前後切換日期、回到今天、切換日／月／議程視圖、路線規劃與重新整理。
class ScheduleHeader extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleHeader({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 820;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade200)),
          ),
          child: isCompact
              ? Column(
                  children: [
                    Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.today, color: primaryColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          data.viewMode == 'month_grid'
                              ? DateFormat('yyyy/MM', AppSettings.instance.language).format(data.selectedDate)
                              : DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(data.selectedDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 24),
                          onPressed: () {
                            if (data.viewMode == 'month_grid') {
                              actions.selectDateAndReload(DateTime(data.selectedDate.year, data.selectedDate.month - 1, 1));
                            } else {
                              actions.selectDateAndReload(data.selectedDate.subtract(const Duration(days: 1)));
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 24),
                          onPressed: () {
                            if (data.viewMode == 'month_grid') {
                              actions.selectDateAndReload(DateTime(data.selectedDate.year, data.selectedDate.month + 1, 1));
                            } else {
                              actions.selectDateAndReload(data.selectedDate.add(const Duration(days: 1)));
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            actions.selectDateAndReload(DateTime.now());
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(context.l10n('calendar_back_to_today'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => actions.openRoutePlanner(
                            date: data.selectedDate,
                            events: data.events,
                          ),
                          icon: const Icon(Icons.alt_route, size: 14, color: Colors.white),
                          label: const Text('路線規劃', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // View mode switcher on mobile (Month Grid, Timeline, Agenda List)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => actions.changeViewMode('month_grid'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: data.viewMode == 'month_grid' ? primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.grid_on_outlined,
                                        size: 13,
                                        color: data.viewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        context.l10n('calendar_view_month'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: data.viewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => actions.changeViewMode('timeline'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: data.viewMode == 'timeline' ? primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.view_day_outlined,
                                        size: 13,
                                        color: data.viewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        context.l10n('calendar_view_timeline'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: data.viewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => actions.changeViewMode('agenda'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: data.viewMode == 'agenda' ? primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.format_list_bulleted_rounded,
                                        size: 13,
                                        color: data.viewMode == 'agenda' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        context.l10n('calendar_view_agenda'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: data.viewMode == 'agenda' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (data.isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      data.viewMode == 'month_grid'
                          ? DateFormat('yyyy/MM', AppSettings.instance.language).format(data.selectedDate)
                          : DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(data.selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 30),
                      onPressed: () {
                        if (data.viewMode == 'month_grid') {
                          actions.selectDateAndReload(DateTime(data.selectedDate.year, data.selectedDate.month - 1, 1));
                        } else {
                          actions.selectDateAndReload(data.selectedDate.subtract(const Duration(days: 1)));
                        }
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 30),
                      onPressed: () {
                        if (data.viewMode == 'month_grid') {
                          actions.selectDateAndReload(DateTime(data.selectedDate.year, data.selectedDate.month + 1, 1));
                        } else {
                          actions.selectDateAndReload(data.selectedDate.add(const Duration(days: 1)));
                        }
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () {
                        actions.selectDateAndReload(DateTime.now());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(context.l10n('calendar_back_to_today'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 路線規劃按鈕
                    ElevatedButton.icon(
                      onPressed: () => actions.openRoutePlanner(
                        date: data.selectedDate,
                        events: data.events,
                      ),
                      icon: const Icon(Icons.alt_route, size: 16, color: Colors.white),
                      label: const Text('路線規劃', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 視圖切換按鈕 (月網格 / 日時間軸 / 議程清單)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => actions.changeViewMode('month_grid'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: data.viewMode == 'month_grid' ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.grid_on_outlined,
                                    size: 15,
                                    color: data.viewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.l10n('calendar_view_month'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: data.viewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => actions.changeViewMode('timeline'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: data.viewMode == 'timeline' ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.view_day_outlined,
                                    size: 15,
                                    color: data.viewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.l10n('calendar_view_timeline'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: data.viewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => actions.changeViewMode('agenda'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: data.viewMode == 'agenda' ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.format_list_bulleted_rounded,
                                    size: 15,
                                    color: data.viewMode == 'agenda' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.l10n('calendar_view_agenda'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: data.viewMode == 'agenda' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (data.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: actions.reload,
                      tooltip: '重新整理行程',
                    ),
                  ],
                ),
              ],
            ),
        );
      },
    );
  }
}
