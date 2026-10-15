import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_result.dart';
import 'package:insurance_helper/screens/visit_projects/schedule_visit_result_bar.dart';
import 'package:insurance_helper/screens/visit_projects/visit_pending_section.dart';
import 'package:insurance_helper/screens/visit_projects/visit_projects_page.dart';
import 'package:insurance_helper/services/visit_pending_service.dart';
import 'package:insurance_helper/services/visit_project_service.dart';
import 'package:insurance_helper/services/visit_result_service.dart';

Map<String, dynamic> eventRow(String id, String title, DateTime startAt, {String? customerId}) {
  return {
    'id': id,
    'title': title,
    'start_at': startAt.toUtc().toIso8601String(),
    'end_at': startAt.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    'customer_id': customerId,
    'deleted_at': null,
  };
}

Future<void> pumpPage(WidgetTester tester, {Size size = const Size(1200, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VisitProjectsPage())));
  await tester.pumpAndSettle();
}

// 專案拜訪頁分成三頁：總覽／待記錄（N）／拜訪紀錄
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.textContaining(label).first);
  await tester.pumpAndSettle();
}

void main() {
  test('行程日期的說法：今天、昨天、其他日期加星期', () {
    final DateTime today = DateTime(2026, 10, 16, 15);
    expect(friendlyEventDate(DateTime(2026, 10, 16, 9), today), '今天');
    expect(friendlyEventDate(DateTime(2026, 10, 15, 20), today), '昨天');
    expect(friendlyEventDate(DateTime(2026, 10, 12, 10), today), '10/12（一）');
  });

  group('還沒記錄結果（離線預覽）', () {
    final DateTime now = DateTime.now();

    setUp(() {
      isOfflineMode = true;
      VisitProjectService.instance.resetOfflineForTest();
      VisitResultService.instance.resetOfflineForTest();
      VisitPendingService.instance.resetOfflineForTest();
      OfflineDataStore.customers = [
        {'id': 'c1', 'name': '王大明', 'nickname': '', 'phone': '', 'deleted_at': null, 'client_status': null},
        {'id': 'c2', 'name': '陳美玲', 'nickname': '', 'phone': '', 'deleted_at': null, 'client_status': null},
      ];
      OfflineDataStore.scheduleEvents = [
        // 1 分鐘前：不管測試在幾點跑都還是「今天」
        eventRow('e1', '保單說明', now.subtract(const Duration(minutes: 1)), customerId: 'c1'),
        eventRow('e2', '續約討論', now.subtract(const Duration(days: 1)), customerId: 'c2'),
        eventRow('e3', '下週再約', now.add(const Duration(days: 2)), customerId: 'c1'), // 還沒到，不列
        eventRow('e4', '個人行程', now.subtract(const Duration(hours: 3))), // 沒有客戶，不列
        eventRow('e5', '很久以前', now.subtract(const Duration(days: 40)), customerId: 'c1'), // 超過 30 天，不列
      ];
    });

    test('只列有客戶、時間已到、30 天內、沒記錄的行程，新的在上面', () async {
      final PendingVisitLists lists = await VisitPendingService.instance.fetchLists(now);
      expect(lists.pending.map((event) => event.eventId).toList(), ['e1', 'e2']);
      expect(lists.recentlyDone, isEmpty);
    });

    test('同一個行程不能記兩筆結果', () async {
      final VisitResultDraft draft = VisitResultDraft(
        projectId: 'offline-project-default',
        customerId: 'c1',
        visitedOn: now,
        result: VisitResult.resultPositive,
        scheduleEventId: 'e1',
      );
      await VisitResultService.instance.createResult(draft);
      expect(() => VisitResultService.instance.createResult(draft), throwsException);
    });

    testWidgets('從清單記錄結果：客戶帶好、移到「已記錄」、客戶狀態更新', (WidgetTester tester) async {
      await pumpPage(tester);
      // 分頁標題直接顯示待記錄筆數
      expect(find.text('待記錄（2）'), findsOneWidget);
      await openTab(tester, '待記錄（');
      expect(find.text('還沒記錄結果（2）'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('昨天・過期未記錄'), findsOneWidget);
      expect(find.text('下週再約'), findsNothing);

      await tester.tap(find.text('記錄結果').first);
      await tester.pumpAndSettle();
      expect(find.text('記錄行程結果'), findsOneWidget);
      expect(find.text('來自行程：保單說明'), findsOneWidget);
      // 客戶已經帶好
      expect(find.widgetWithText(OutlinedButton, '王大明'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '✔ 有意願／已成交'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(find.text('還沒記錄結果（1）'), findsOneWidget);
      expect(find.text('已記錄（最近 7 天）'), findsOneWidget);
      expect(find.text('已記錄 ✔'), findsOneWidget);
      expect(OfflineDataStore.customers.first['client_status'], 'positive');
    });

    testWidgets('沒拜訪：移出清單、不算進度；按復原回來', (WidgetTester tester) async {
      await pumpPage(tester);
      await openTab(tester, '待記錄（');
      await tester.tap(find.text('沒拜訪').first);
      await tester.pumpAndSettle();
      expect(find.text('還沒記錄結果（1）'), findsOneWidget);
      expect(find.text('復原'), findsOneWidget);
      await openTab(tester, '總覽');
      expect(find.text('0 / 20 次'), findsOneWidget);

      await openTab(tester, '待記錄（');
      await tester.tap(find.text('復原'));
      await tester.pumpAndSettle();
      expect(find.text('還沒記錄結果（2）'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('今日行程的行程視窗：時間已到的客戶行程顯示「記錄結果」，還沒到的不顯示', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            ScheduleVisitResultBar(eventId: 'e1'),
            ScheduleVisitResultBar(eventId: 'e3'),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('這次拜訪 王大明 還沒記錄結果'), findsOneWidget);
      expect(find.text('記錄結果'), findsOneWidget);

      await tester.tap(find.text('沒拜訪'));
      await tester.pumpAndSettle();
      expect(find.text('這次標記為「沒拜訪」（不算進度）'), findsOneWidget);
      expect(find.text('復原'), findsOneWidget);
    });

    testWidgets('手機寬度：待記錄清單不超出', (WidgetTester tester) async {
      await pumpPage(tester, size: const Size(375, 1200));
      await openTab(tester, '待記錄（');
      expect(tester.takeException(), isNull);
      expect(find.text('還沒記錄結果（2）'), findsOneWidget);
    });
  });
}
