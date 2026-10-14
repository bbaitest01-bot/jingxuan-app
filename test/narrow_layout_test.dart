import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_page.dart';
import 'package:insurance_helper/screens/visit_records/visit_records_page.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

// 手機寬度（iPhone SE／一般手機約 375）；版面擠壞時 Flutter 會丟出「overflowed」錯誤讓測試失敗
Future<void> pumpNarrow(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  late VisitRecord linkedRecord;

  setUp(() async {
    isOfflineMode = true;
    VisitRecordService.instance.clearOfflineRecordsForTest();
    OfflineDataStore.customers = [
      {'id': 'c1', 'name': '王大明', 'nickname': '大明哥', 'phone': '0912345678', 'email': 'wang@example.com', 'tags': ['高資產', '醫療險'], 'notes': '備註', 'custom_attributes': {}, 'deleted_at': null},
    ];
    final VisitRecord record = await VisitRecordService.instance.createRecord(title: '2026/10/14 15:30 拜訪紀錄', rawTranscript: '今天拜訪王大明，討論醫療險與儲蓄險');
    linkedRecord = await VisitRecordService.instance.updateCustomerLink(record, const VisitCustomerOption(id: 'c1', name: '王大明'));
  });

  testWidgets('手機寬度：拜訪紀錄列表不超出，也不重複放頁面標題', (WidgetTester tester) async {
    await pumpNarrow(tester, const VisitRecordsPage());
    expect(tester.takeException(), isNull);
    // 頁首已經有「拜訪紀錄」，頁面內不再放大標題
    expect(find.text('拜訪紀錄'), findsNothing);
    expect(find.text('錄音新增'), findsOneWidget);
    expect(find.text('新增紀錄'), findsOneWidget);
  });

  testWidgets('手機寬度：拜訪紀錄單篇頁不超出', (WidgetTester tester) async {
    await pumpNarrow(tester, VisitRecordsPage(recordId: linkedRecord.id));
    expect(tester.takeException(), isNull);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.text('刪除'), findsOneWidget);
    expect(find.text('王大明'), findsOneWidget);
  });

  testWidgets('手機寬度：客戶細節整頁不超出', (WidgetTester tester) async {
    await pumpNarrow(tester, const CustomerDetailPage(customerId: 'c1'));
    expect(tester.takeException(), isNull);
    expect(find.text('王大明（大明哥）'), findsOneWidget);
    expect(find.text('編輯'), findsOneWidget);
  });
}
