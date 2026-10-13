import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/screens/visit_records/visit_records_page.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    isOfflineMode = true;
    VisitRecordService.instance.clearOfflineRecordsForTest();
  });

  testWidgets('沒有紀錄時列表顯示空狀態與「新增紀錄」按鈕', (WidgetTester tester) async {
    await pumpPage(tester, const VisitRecordsPage());
    expect(find.text('還沒有拜訪紀錄'), findsOneWidget);
    expect(find.text('新增紀錄'), findsOneWidget);
  });

  testWidgets('列表顯示標題與狀態', (WidgetTester tester) async {
    await VisitRecordService.instance.createRecord(title: '拜訪王先生', rawTranscript: '討論醫療險');
    await pumpPage(tester, const VisitRecordsPage());
    expect(find.text('拜訪王先生'), findsOneWidget);
    expect(find.text('尚未整理'), findsOneWidget);
    expect(find.text('討論醫療險'), findsOneWidget);
  });

  testWidgets('單篇頁顯示原始轉錄，「複製原始轉錄」後儲存成整理後內容', (WidgetTester tester) async {
    final VisitRecord record = await VisitRecordService.instance.createRecord(title: '拜訪王先生', rawTranscript: '討論醫療險');
    await pumpPage(tester, VisitRecordsPage(recordId: record.id));
    expect(find.text('原始轉錄'), findsOneWidget);
    expect(find.text('整理後內容'), findsOneWidget);

    await tester.tap(find.text('複製原始轉錄'));
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final VisitRecord? saved = await VisitRecordService.instance.fetchRecord(record.id);
    expect(saved?.organizedContent, '討論醫療險');
    // 讓提示訊息的計時器跑完
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('找不到的編號顯示提示與返回按鈕', (WidgetTester tester) async {
    await pumpPage(tester, const VisitRecordsPage(recordId: 'not-exist'));
    expect(find.textContaining('找不到這篇拜訪紀錄'), findsOneWidget);
    expect(find.text('返回拜訪紀錄列表'), findsOneWidget);
  });

  testWidgets('列表有「錄音新增」，打開後是錄音視窗；離線模式按錄音會提示無法使用', (WidgetTester tester) async {
    await pumpPage(tester, const VisitRecordsPage());
    expect(find.text('錄音新增'), findsOneWidget);

    await tester.tap(find.text('錄音新增'));
    await tester.pumpAndSettle();
    expect(find.text('錄音新增拜訪紀錄'), findsOneWidget);
    expect(find.textContaining('最長 10 分鐘'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fiber_manual_record));
    await tester.pump();
    expect(find.textContaining('離線預覽模式無法使用語音轉錄'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(find.text('錄音新增拜訪紀錄'), findsNothing);
  });
}
