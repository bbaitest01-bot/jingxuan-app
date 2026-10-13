import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/screens/trash/trash_item_cards.dart';
import 'package:insurance_helper/services/schedule_service.dart';

ScheduleEvent buildEvent(String title) {
  final DateTime start = DateTime(2026, 10, 15, 14, 0);
  return ScheduleEvent(
    id: '',
    profileId: '',
    title: title,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
  );
}

void main() {
  group('ScheduleEvent 的 deleted_at', () {
    test('正常行程寫入資料時不帶 deleted_at（避免一般更新改到它）', () {
      expect(buildEvent('拜訪').toJson().containsKey('deleted_at'), isFalse);
    });

    test('垃圾桶裡的行程可以讀回刪除時間', () {
      final Map<String, dynamic> json = buildEvent('拜訪').toJson();
      json['deleted_at'] = DateTime.utc(2026, 10, 13).toIso8601String();
      expect(ScheduleEvent.fromJson(json).deletedAt, isNotNull);
    });
  });

  group('trashDaysLeft 剩餘天數', () {
    test('今天刪除剩 30 天；10 天前刪除剩 20 天；超過 30 天是 0', () {
      final DateTime now = DateTime.now();
      expect(trashDaysLeft(now), 30);
      expect(trashDaysLeft(now.subtract(const Duration(days: 10))), 20);
      expect(trashDaysLeft(now.subtract(const Duration(days: 40))), 0);
    });
  });

  group('離線模式：刪除 → 垃圾桶 → 還原 → 永久刪除', () {
    setUp(() {
      isOfflineMode = true;
      OfflineDataStore.scheduleEvents = [];
    });

    test('完整流程', () async {
      final ScheduleService service = ScheduleService.instance;
      final ScheduleEvent created = await service.createEvent(buildEvent('拜訪王小明'));

      // 刪除：行程列表看不到，垃圾桶看得到
      await service.deleteEvent(created.id);
      expect(await service.fetchEvents(), isEmpty);
      final List<ScheduleEvent> trash = await service.fetchDeletedEvents();
      expect(trash.single.title, '拜訪王小明');
      expect(trash.single.deletedAt, isNotNull);

      // 還原：回到行程列表，垃圾桶清空
      await service.restoreEvent(created.id);
      expect((await service.fetchEvents()).single.title, '拜訪王小明');
      expect(await service.fetchDeletedEvents(), isEmpty);

      // 再刪一次後永久刪除：兩邊都沒有
      await service.deleteEvent(created.id);
      await service.deleteEventForever(created.id);
      expect(await service.fetchEvents(), isEmpty);
      expect(await service.fetchDeletedEvents(), isEmpty);
    });
  });

  test('行程卡片的時間格式', () {
    expect(DeletedScheduleCard.formatEventTime(buildEvent('拜訪')), '2026/10/15 (週四) 14:00–15:00');
  });
}
