import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/screens/visit_records/visit_records_page.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

const List<VisitCustomerOption> sampleOptions = [
  VisitCustomerOption(id: 'c1', name: '王小明', nickname: '小明', phone: '0912-345-678'),
  VisitCustomerOption(id: 'c2', name: '陳大同', phone: '0922111222'),
];

void main() {
  group('客戶選項搜尋', () {
    test('空白顯示全部；可用姓名、暱稱、電話片段搜尋', () {
      expect(VisitRecordService.filterCustomerOptions(sampleOptions, '').length, 2);
      expect(VisitRecordService.filterCustomerOptions(sampleOptions, '陳').single.id, 'c2');
      expect(VisitRecordService.filterCustomerOptions(sampleOptions, '小明').single.id, 'c1');
      expect(VisitRecordService.filterCustomerOptions(sampleOptions, '345678').single.id, 'c1');
    });

    test('「王1」這種文字＋數字不會被當成電話比對', () {
      expect(VisitRecordService.filterCustomerOptions(sampleOptions, '王1'), isEmpty);
    });
  });

  test('讀取時一起帶出連結客戶名字與是否在垃圾桶', () {
    final VisitRecord record = VisitRecord.fromJson({
      'id': 'r1',
      'title': '拜訪',
      'customer_id': 'c1',
      'customers': {'name': '王小明', 'deleted_at': '2026-10-14T00:00:00Z'},
    });
    expect(record.customerName, '王小明');
    expect(record.isCustomerDeleted, isTrue);
  });

  group('離線模式：單篇頁連結、更換、取消客戶', () {
    setUp(() {
      isOfflineMode = true;
      VisitRecordService.instance.clearOfflineRecordsForTest();
      OfflineDataStore.customers = [
        {'id': 'c1', 'name': '王小明', 'nickname': '', 'phone': '0912345678', 'deleted_at': null},
        {'id': 'c2', 'name': '陳大同', 'nickname': '', 'phone': '', 'deleted_at': null},
        {'id': 'c3', 'name': '已刪除客戶', 'nickname': '', 'phone': '', 'deleted_at': '2026-10-01'},
      ];
    });

    testWidgets('選擇 → 顯示名字；取消連結 → 回到尚未連結', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final VisitRecord record = await VisitRecordService.instance.createRecord(title: '拜訪', rawTranscript: '內容');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: VisitRecordsPage(recordId: record.id))));
      await tester.pumpAndSettle();
      expect(find.text('尚未連結客戶'), findsOneWidget);

      await tester.tap(find.text('選擇客戶'));
      await tester.pumpAndSettle();
      // 垃圾桶裡的客戶不會出現在選單
      expect(find.text('已刪除客戶'), findsNothing);
      await tester.tap(find.text('王小明'));
      await tester.pumpAndSettle();
      expect(find.text('王小明'), findsOneWidget);
      expect(find.text('更換'), findsOneWidget);

      await tester.tap(find.text('取消連結'));
      await tester.pumpAndSettle();
      expect(find.text('尚未連結客戶'), findsOneWidget);
      final VisitRecord? reloaded = await VisitRecordService.instance.fetchRecord(record.id);
      expect(reloaded?.customerId, isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
