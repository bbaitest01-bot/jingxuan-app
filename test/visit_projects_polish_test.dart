import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_project.dart';
import 'package:insurance_helper/models/visit_result.dart';
import 'package:insurance_helper/screens/visit_projects/visit_projects_page.dart';
import 'package:insurance_helper/services/visit_pending_service.dart';
import 'package:insurance_helper/services/visit_project_service.dart';
import 'package:insurance_helper/services/visit_result_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPage(WidgetTester tester, {Size size = const Size(1200, 1800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VisitProjectsPage())));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.textContaining(label).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isOfflineMode = true;
    VisitProjectService.instance.resetOfflineForTest();
    VisitResultService.instance.resetOfflineForTest();
    VisitPendingService.instance.resetOfflineForTest();
    OfflineDataStore.scheduleEvents = [];
    OfflineDataStore.customers = [
      {'id': 'c1', 'name': '王大明', 'nickname': '', 'phone': '', 'tags': <String>[], 'deleted_at': null, 'client_status': null},
      {'id': 'c2', 'name': '陳美玲', 'nickname': '', 'phone': '', 'tags': <String>[], 'deleted_at': null, 'client_status': null},
    ];
  });

  testWidgets('分三頁：總覽有圖表和專案、待記錄、拜訪紀錄各自顯示', (WidgetTester tester) async {
    await pumpPage(tester);
    expect(find.text('總覽'), findsOneWidget);
    expect(find.text('待記錄（0）'), findsOneWidget);
    expect(find.text('拜訪成效'), findsOneWidget);
    expect(find.text('日常拜訪'), findsWidgets);
    expect(find.text('拜訪結果紀錄'), findsNothing);

    await openTab(tester, '待記錄（');
    expect(find.textContaining('目前沒有要記錄的行程'), findsOneWidget);
    expect(find.text('拜訪成效'), findsNothing);

    await openTab(tester, '拜訪紀錄');
    expect(find.text('拜訪結果紀錄'), findsOneWidget);
    // 上方按鈕在每一頁都在
    expect(find.text('記錄拜訪'), findsOneWidget);
    expect(find.text('建立專案'), findsOneWidget);
  });

  testWidgets('圖表的週／月／年在右邊、期間切換在右邊（照模型）', (WidgetTester tester) async {
    await pumpPage(tester);
    final double titleX = tester.getTopLeft(find.text('拜訪成效')).dx;
    final double rangeX = tester.getTopLeft(find.text('週')).dx;
    final double periodX = tester.getTopLeft(find.byTooltip('上一期')).dx;
    // 畫面寬 1200：標題在左、週月年和期間都在右半邊
    expect(titleX, lessThan(200));
    expect(rangeX, greaterThan(800));
    expect(periodX, greaterThan(800));
  });

  testWidgets('看名單與紀錄：名單沒拜訪的可直接記錄，記完顯示結果與次數，卡片進度跟著變', (WidgetTester tester) async {
    await VisitProjectService.instance.createProject(const VisitProjectDraft(
      title: '十月健檢',
      periodType: VisitProject.periodMonth,
      targetCount: 3,
      members: {'c1': '王大明', 'c2': '陳美玲'},
    ));
    await pumpPage(tester);
    // 第二張卡片（十月健檢）的「看名單與紀錄」
    await tester.tap(find.text('看名單與紀錄').at(1));
    await tester.pumpAndSettle();
    expect(find.text('還沒拜訪・記錄'), findsNWidgets(2));
    expect(find.text('這一期還沒有拜訪。'), findsOneWidget);

    await tester.tap(find.text('還沒拜訪・記錄').first);
    await tester.pumpAndSettle();
    // 客戶已帶好、專案預設這個專案
    expect(find.widgetWithText(OutlinedButton, '王大明'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '✔ 有意願／已成交'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(find.text('還沒拜訪・記錄'), findsOneWidget);
    expect(find.textContaining('・1 次', findRichText: true), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3 次'), findsOneWidget);
  });

  testWidgets('拜訪紀錄的日期顯示「今天」', (WidgetTester tester) async {
    await VisitResultService.instance.createResult(VisitResultDraft(
      projectId: 'offline-project-default',
      projectTitle: '日常拜訪',
      customerId: 'c1',
      customerName: '王大明',
      visitedOn: DateTime.now(),
      result: VisitResult.resultConsidering,
    ));
    await pumpPage(tester);
    await openTab(tester, '拜訪紀錄');
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('手機寬度：分頁列、總覽卡片按鈕不超出', (WidgetTester tester) async {
    await pumpPage(tester, size: const Size(375, 1600));
    expect(tester.takeException(), isNull);
    expect(find.text('看名單與紀錄'), findsOneWidget);
  });
}
