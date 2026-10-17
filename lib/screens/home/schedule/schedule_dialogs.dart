import 'package:flutter/material.dart';
import '../../../models/schedule_event.dart';
import '../../../widgets/custom_toast.dart';
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

/// 從語音排程的 AI 結果取出行程；沒有行程或解析失敗時回傳 null
ScheduleEvent? parseVoiceSchedulerEvent(Map<String, dynamic> result) {
  final Map<String, dynamic>? eventMap = result['event'] as Map<String, dynamic>?;
  if (eventMap == null) return null;
  try {
    return ScheduleEvent.fromJson(eventMap);
  } catch (e) {
    debugPrint('解析語音行程失敗，改用預設行程物件: $e');
    return null;
  }
}

/// 依 AI 判斷顯示提示：黃燈表示資訊不完整，列出缺漏；綠燈請使用者確認後儲存
void showVoiceSchedulerResultToast(BuildContext context, Map<String, dynamic> result) {
  final String status = result['status'] as String? ?? 'green';
  if (status == 'yellow') {
    final List<String> warnings = List<String>.from(result['warning_messages'] ?? []);
    String warningText = '行程資訊有所遺漏，請核對並補充細節！';
    if (warnings.isNotEmpty) {
      warningText = '⚠️ ${warnings.join('； ')}';
    }
    CustomToast.show(context, warningText, ToastType.warning);
  } else {
    CustomToast.show(context, '語音辨識完成，請確認並儲存行程！', ToastType.success);
  }
}

/// 開啟日期選擇器。使用者取消時回傳 null。
/// 顏色直接沿用 App 主題（lib/theme/），跟著主題色與明暗模式變，不用另外設定。
Future<DateTime?> showScheduleDatePicker(BuildContext context, DateTime initialDate) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
}
