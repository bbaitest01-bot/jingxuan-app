import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/screens/home/schedule/schedule_page_state.dart';

ScheduleEvent eventAt(String id, DateTime startAt, DateTime endAt) {
  return ScheduleEvent(id: id, profileId: 'u1', title: id, startAt: startAt, endAt: endAt);
}

void main() {
  test('S20：路線規劃只拿選到那一天的行程（月網格讀進來的是整個月）', () {
    final ScheduleViewData data = ScheduleViewData(
      selectedDate: DateTime(2026, 11, 5, 12),
      viewMode: 'month_grid',
      isLoading: false,
      events: [
        eventAt('當天', DateTime(2026, 11, 5, 10), DateTime(2026, 11, 5, 11)),
        eventAt('前一天', DateTime(2026, 11, 4, 10), DateTime(2026, 11, 4, 11)),
        eventAt('後一天', DateTime(2026, 11, 6, 10), DateTime(2026, 11, 6, 11)),
        eventAt('跨到當天', DateTime(2026, 11, 4, 22), DateTime(2026, 11, 5, 1)),
      ],
    );
    final List<String> ids = data.eventsOnSelectedDay.map((ScheduleEvent event) => event.id).toList();
    expect(ids, ['當天', '跨到當天']);
  });
}
