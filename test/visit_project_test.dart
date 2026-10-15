import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_project.dart';
import 'package:insurance_helper/screens/visit_projects/visit_projects_page.dart';
import 'package:insurance_helper/services/visit_project_service.dart';

VisitProject buildProject({
  String id = 'p1',
  String periodType = VisitProject.periodMonth,
  DateTime? startDate,
  DateTime? endDate,
  int targetCount = 10,
  Map<String, String> members = const {},
}) {
  return VisitProject(
    id: id,
    title: '測試專案',
    periodType: periodType,
    startDate: startDate,
    endDate: endDate,
    targetCount: targetCount,
    members: members,
    createdAt: DateTime(2026, 10, 1),
  );
}

VisitResultSummary buildResult(String customerId, DateTime visitedOn, String result, {String projectId = 'p1'}) {
  return VisitResultSummary(projectId: projectId, customerId: customerId, visitedOn: visitedOn, result: result);
}

Future<void> pumpPage(WidgetTester tester, {Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VisitProjectsPage())));
  await tester.pumpAndSettle();
}

void main() {
  // 2026-10-15 是週四
  final DateTime today = DateTime(2026, 10, 15);

  group('這一期的起訖日', () {
    test('每週：週一到週日', () {
      final period = buildProject(periodType: VisitProject.periodWeek).currentPeriod(today);
      expect(period.start, DateTime(2026, 10, 12));
      expect(period.end, DateTime(2026, 10, 18));
    });

    test('每月：1 號到月底', () {
      final period = buildProject().currentPeriod(today);
      expect(period.start, DateTime(2026, 10, 1));
      expect(period.end, DateTime(2026, 10, 31));
    });

    test('每年、每天', () {
      expect(buildProject(periodType: VisitProject.periodYear).currentPeriod(today).start, DateTime(2026, 1, 1));
      expect(buildProject(periodType: VisitProject.periodDay).currentPeriod(today).end, today);
    });

    test('固定期間：就是設定的起訖日', () {
      final VisitProject project = buildProject(
        periodType: VisitProject.periodRange,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      expect(project.periodText(today), '固定期間 11/1～11/30');
    });
  });

  group('進度計算', () {
    test('只算這一期、這個專案；同一人多次都算；名單列出還沒拜訪的', () {
      final VisitProject project = buildProject(members: {'c1': '王大明', 'c2': '陳美玲'});
      final List<VisitResultSummary> results = [
        buildResult('c1', DateTime(2026, 10, 3), 'positive'),
        buildResult('c1', DateTime(2026, 10, 10), 'considering'),
        buildResult('c3', DateTime(2026, 10, 14), 'negative'),
        buildResult('c2', DateTime(2026, 9, 30), 'positive'), // 上個月，不算
        buildResult('c2', DateTime(2026, 10, 5), 'positive', projectId: 'p2'), // 別的專案，不算
      ];
      final VisitProjectProgress progress = VisitProjectProgress.calculate(project, results, today);
      expect(progress.visitCount, 3);
      expect(progress.positiveCount, 1);
      expect(progress.consideringCount, 1);
      expect(progress.negativeCount, 1);
      expect(progress.unvisitedMemberNames, ['陳美玲']);
      expect(progress.ratioOf(10), closeTo(0.3, 0.001));
    });

    test('超過目標時進度條停在 100%', () {
      final VisitProjectProgress progress = VisitProjectProgress.calculate(
        buildProject(targetCount: 1),
        [buildResult('c1', today, 'positive'), buildResult('c2', today, 'positive')],
        today,
      );
      expect(progress.ratioOf(1), 1.0);
    });

    test('讀結果從最早的這一期開始日算起', () {
      final List<VisitProject> projects = [
        buildProject(periodType: VisitProject.periodWeek),
        buildProject(periodType: VisitProject.periodRange, startDate: DateTime(2026, 9, 1), endDate: DateTime(2026, 12, 31)),
      ];
      expect(VisitProjectService.earliestPeriodStart(projects, today), DateTime(2026, 9, 1));
    });
  });

  group('填寫檢查', () {
    test('名稱、目標次數、固定期間日期', () {
      expect(VisitProjectService.validateDraft(const VisitProjectDraft(title: ' ', periodType: 'month', targetCount: 5)), '請輸入專案名稱');
      expect(VisitProjectService.validateDraft(const VisitProjectDraft(title: 'A', periodType: 'month', targetCount: 0)), '目標次數至少 1 次');
      expect(VisitProjectService.validateDraft(const VisitProjectDraft(title: 'A', periodType: 'range', targetCount: 5)), '請選擇開始日和結束日');
      expect(
        VisitProjectService.validateDraft(VisitProjectDraft(
          title: 'A',
          periodType: 'range',
          targetCount: 5,
          startDate: DateTime(2026, 11, 30),
          endDate: DateTime(2026, 11, 1),
        )),
        '結束日不能早於開始日',
      );
      expect(VisitProjectService.validateDraft(const VisitProjectDraft(title: 'A', periodType: 'week', targetCount: 5)), isNull);
    });
  });

  group('專案拜訪頁（離線預覽）', () {
    setUp(() {
      isOfflineMode = true;
      VisitProjectService.instance.resetOfflineForTest();
      OfflineDataStore.customers = [
        {'id': 'c1', 'name': '王大明', 'nickname': '', 'phone': '0912345678', 'deleted_at': null},
        {'id': 'c2', 'name': '陳美玲', 'nickname': '', 'phone': '0922333444', 'deleted_at': null},
      ];
    });

    testWidgets('第一次打開自動有「日常拜訪」，不能刪除', (WidgetTester tester) async {
      await pumpPage(tester);
      expect(find.text('日常拜訪'), findsOneWidget);
      expect(find.text('預設'), findsOneWidget);
      expect(find.text('0 / 20 次'), findsOneWidget);
      expect(find.text('沒有名單，任何客戶都算'), findsOneWidget);
      expect(find.text('刪除'), findsNothing);
    });

    testWidgets('建立每週專案並選名單，卡片顯示名單還沒拜訪的人', (WidgetTester tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('建立專案'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '專案名稱'), '每週回訪');
      await tester.tap(find.text('每月').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('每週').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '目標次數（每一期）'), '5');

      await tester.tap(find.text('選擇名單'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('王大明'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(find.text('每週回訪'), findsOneWidget);
      expect(find.text('0 / 5 次'), findsOneWidget);
      expect(find.textContaining('名單 1 人，還有 1 人沒拜訪：王大明'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
    });

    testWidgets('固定期間沒選日期時擋下並提示', (WidgetTester tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('建立專案'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '專案名稱'), '十一月衝刺');
      await tester.tap(find.text('固定期間'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      // 提示在下一個畫面才加上去，多跑兩次畫面
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('請選擇開始日和結束日'), findsOneWidget);
      // 視窗還開著
      expect(find.text('建立專案'), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('刪除專案前確認，確認後卡片消失', (WidgetTester tester) async {
      await VisitProjectService.instance.createProject(
        const VisitProjectDraft(title: '要刪的專案', periodType: VisitProject.periodMonth, targetCount: 3),
      );
      await pumpPage(tester);
      expect(find.text('要刪的專案'), findsOneWidget);

      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(find.text('刪除「要刪的專案」？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();
      expect(find.text('要刪的專案'), findsNothing);
      expect(find.text('日常拜訪'), findsOneWidget);
    });

    testWidgets('手機寬度：卡片與按鈕不超出', (WidgetTester tester) async {
      await VisitProjectService.instance.createProject(VisitProjectDraft(
        title: '名稱很長的十一月轉介紹衝刺專案',
        periodType: VisitProject.periodRange,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        targetCount: 15,
        members: const {'c1': '王大明', 'c2': '陳美玲'},
      ));
      await pumpPage(tester, size: const Size(375, 812));
      expect(tester.takeException(), isNull);
      expect(find.text('建立專案'), findsOneWidget);
      expect(find.text('固定期間 11/1～11/30'), findsOneWidget);
    });
  });
}
