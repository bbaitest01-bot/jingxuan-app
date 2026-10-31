import 'package:flutter/material.dart';
import '../../../services/app_settings.dart';
import 'schedule_agenda_view.dart';
import 'schedule_day_detail_panel.dart';
import 'schedule_day_view.dart';
import 'schedule_header.dart';
import 'schedule_mini_calendar_panel.dart';
import 'schedule_month_view.dart';
import 'schedule_page_state.dart';
import 'schedule_week_strip.dart';
import '../../../widgets/tour_target.dart';

/// 「今日行程」整頁：把工具列、主視圖（日／月／議程）與右側面板組合起來。
/// 電腦版：主視圖右邊依視圖顯示當日詳情或小月曆。
/// 手機版：上方多一條週曆列，主視圖可以下拉重新整理。
class SchedulePage extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;
  final bool isWideScreen;

  const SchedulePage({
    super.key,
    required this.data,
    required this.actions,
    required this.isWideScreen,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (isWideScreen) {
      body = _buildWideLayout();
    } else {
      body = _buildNarrowLayout();
    }

    return Column(
      children: [
        ScheduleHeader(data: data, actions: actions),
        Expanded(child: body),
      ],
    );
  }

  // 依目前的視圖選出主畫面
  Widget _buildMainView() {
    Widget view = ScheduleDayView(data: data, actions: actions);
    if (data.viewMode == 'month_grid') view = ScheduleMonthView(data: data, actions: actions);
    if (data.viewMode == 'agenda') view = ScheduleAgendaView(data: data, actions: actions);
    // 新手導覽第 2 步亮行程主畫面
    return TourTarget(id: 'schedule.main', child: view);
  }

  // 電腦版：主視圖＋右側面板。月網格配當日詳情、日時間軸配小月曆、議程清單不放右欄（滿版）
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMainView()),
        if (data.viewMode == 'month_grid')
          ScheduleDayDetailPanel(data: data, actions: actions)
        else if (data.viewMode == 'timeline')
          ScheduleMiniCalendarPanel(data: data, actions: actions),
      ],
    );
  }

  // 手機版：週曆列＋可下拉重新整理的主視圖
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        ScheduleWeekStrip(data: data, actions: actions),
        Expanded(
          child: RefreshIndicator(
            onRefresh: actions.reload,
            color: AppSettings.instance.primaryColor,
            child: _buildMainView(),
          ),
        ),
      ],
    );
  }
}
