import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import '../../../services/app_settings.dart';
import '../../../widgets/route_planner_dialog.dart';
import '../../../widgets/schedule_event_dialog.dart';
import '../../../widgets/voice_scheduler_overlay.dart';

// 今日行程用到的各種彈出視窗。這裡只負責「打開視窗、把結果交回去」，
// 拿到結果後要重新讀取或顯示提示，由 HomeScreen 決定。

/// 開啟行程編輯視窗（手機版從底部滑出，電腦版是置中對話框）。
/// event 傳 null 代表新增。回傳 'created'／'updated'／'deleted'，使用者取消時回傳 null。
Future<dynamic> showScheduleEventEditor(
  BuildContext context, {
  required DateTime initialDate,
  ScheduleEvent? event,
}) async {
  final bool isMobile = MediaQuery.of(context).size.width < 768;
  if (isMobile) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScheduleEventDialog(
        initialDate: initialDate,
        eventToEdit: event,
        isBottomSheet: true,
      ),
    );
  }
  return showDialog<dynamic>(
    context: context,
    builder: (ctx) => ScheduleEventDialog(
      initialDate: initialDate,
      eventToEdit: event,
    ),
  );
}

/// 開啟多站路線規劃視窗（手機版從底部滑出，電腦版是置中對話框）
void showRoutePlanner(
  BuildContext context, {
  required DateTime date,
  required List<ScheduleEvent> events,
}) {
  final bool isMobile = MediaQuery.of(context).size.width < 768;
  if (isMobile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutePlannerDialog(
        selectedDate: date,
        events: events,
        isBottomSheet: true,
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => RoutePlannerDialog(
        selectedDate: date,
        events: events,
      ),
    );
  }
}

/// 開啟全螢幕的語音排程錄音畫面。
/// 回傳 AI 解析結果（含 status、event、warning_messages），使用者取消時回傳 null。
Future<Map<String, dynamic>?> showVoiceSchedulerOverlay(BuildContext context) {
  return showGeneralDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'VoiceScheduler',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return const VoiceSchedulerOverlay();
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: child);
    },
  );
}

/// 開啟日期選擇器，顏色跟著主題色與深淺模式。使用者取消時回傳 null。
Future<DateTime?> showScheduleDatePicker(BuildContext context, DateTime initialDate) {
  final Color primaryColor = AppSettings.instance.primaryColor;
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    builder: (context, child) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      ColorScheme colorScheme;
      if (isDark) {
        colorScheme = ColorScheme.dark(
          primary: primaryColor,
          onPrimary: Colors.white,
          surface: const Color(0xFF161B22),
          onSurface: Colors.white,
        );
      } else {
        colorScheme = ColorScheme.light(
          primary: primaryColor,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(colorScheme: colorScheme),
        child: child!,
      );
    },
  );
}
