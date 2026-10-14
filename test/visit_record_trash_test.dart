import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/screens/trash_bin_screen.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

void main() {
  setUp(() {
    isOfflineMode = true;
    VisitRecordService.instance.clearOfflineRecordsForTest();
    OfflineDataStore.customers = [];
    OfflineDataStore.scheduleEvents = [];
  });

  test('離線模式：刪除 → 列表看不到、垃圾桶看得到 → 還原 → 永久刪除', () async {
    final VisitRecordService service = VisitRecordService.instance;
    final VisitRecord record = await service.createRecord(title: '拜訪王先生', rawTranscript: '內容');

    await service.moveToTrash(record.id);
    expect(await service.fetchMyRecords(), isEmpty);
    expect(await service.fetchRecord(record.id), isNull);
    final List<VisitRecord> trash = await service.fetchDeletedRecords();
    expect(trash.single.title, '拜訪王先生');
    expect(trash.single.deletedAt, isNotNull);

    await service.restoreRecord(record.id);
    expect((await service.fetchMyRecords()).single.id, record.id);
    expect(await service.fetchDeletedRecords(), isEmpty);

    await service.moveToTrash(record.id);
    await service.deleteRecordForever(record.id);
    expect(await service.fetchMyRecords(), isEmpty);
    expect(await service.fetchDeletedRecords(), isEmpty);
  });

  testWidgets('垃圾桶有「拜訪紀錄」分類（取代語音草稿），可還原', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final VisitRecord record = await VisitRecordService.instance.createRecord(title: '拜訪陳經理', rawTranscript: '討論保單');
    await VisitRecordService.instance.moveToTrash(record.id);

    await tester.pumpWidget(const MaterialApp(home: TrashBinScreen()));
    await tester.pumpAndSettle();
    expect(find.text('語音草稿 (0)'), findsNothing);
    expect(find.text('拜訪紀錄 (1)'), findsOneWidget);

    await tester.tap(find.text('拜訪紀錄 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('拜訪陳經理'), findsOneWidget);
    expect(find.text('剩 30 天'), findsOneWidget);

    await tester.tap(find.text('還原紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('拜訪紀錄 (0)'), findsOneWidget);
    expect((await VisitRecordService.instance.fetchMyRecords()).single.id, record.id);
    await tester.pump(const Duration(seconds: 5));
  });
}
