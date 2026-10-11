import '../../../models/schedule_event.dart';

/// 今日行程各畫面要「顯示」的資料，由 HomeScreen 統一保管後傳進來。
/// 把這幾樣打包成一個物件，各個小畫面的參數才不會落落長。
class ScheduleViewData {
  /// 目前選到的日期
  final DateTime selectedDate;

  /// 目前已讀進來的行程（範圍依視圖不同：日視圖是當天；月與議程是整個月前後延伸）
  final List<ScheduleEvent> events;

  /// 是否正在讀取行程（顯示轉圈圈用）
  final bool isLoading;

  /// 目前的視圖：'timeline'（日時間軸）、'month_grid'（月網格）、'agenda'（議程清單）
  final String viewMode;

  const ScheduleViewData({
    required this.selectedDate,
    required this.events,
    required this.isLoading,
    required this.viewMode,
  });
}

/// 今日行程各畫面可以「做的事」。畫面只負責呼叫，實際處理都在 HomeScreen。
class ScheduleActions {
  /// 只換選到的日期，不重新讀取行程（手機版週曆列、日期選擇器目前是這樣）
  final void Function(DateTime newDate) selectDate;

  /// 換選到的日期，並在背景重新讀取行程
  final void Function(DateTime newDate) selectDateAndReload;

  /// 重新讀取行程（會顯示讀取中提示）。
  /// 回傳 Future，下拉重新整理時，轉圈圈才會等讀取完成才消失
  final Future<void> Function() reload;

  /// 切換視圖（日／月／議程）
  final void Function(String newViewMode) changeViewMode;

  /// 開啟行程編輯視窗；傳 null 代表新增行程
  final void Function(ScheduleEvent? event) openEventEditor;

  /// 開啟多站路線規劃視窗
  final void Function({required DateTime date, required List<ScheduleEvent> events}) openRoutePlanner;

  /// 開啟日期選擇器（點月份標題時）
  final void Function() pickDate;

  const ScheduleActions({
    required this.selectDate,
    required this.selectDateAndReload,
    required this.reload,
    required this.changeViewMode,
    required this.openEventEditor,
    required this.openRoutePlanner,
    required this.pickDate,
  });
}
