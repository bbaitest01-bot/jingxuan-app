import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_project.dart';
import 'package:insurance_helper/models/visit_result.dart';
import 'package:insurance_helper/screens/visit_projects/visit_projects_page.dart';
import 'package:insurance_helper/screens/visit_projects/visit_result_list_section.dart';
import 'package:insurance_helper/services/visit_project_service.dart';
import 'package:insurance_helper/services/visit_result_service.dart';

Future<void> pumpPage(WidgetTester tester, {Size size = const Size(1200, 1400)}) async {
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

// 從上方按鈕記錄一筆：選客戶、選結果、儲存
Future<void> recordVisit(WidgetTester tester, {required String customerName, required String resultText}) async {
  await tester.tap(find.widgetWithText(FilledButton, '記錄拜訪').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('選擇客戶'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(customerName).last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, resultText));
  await tester.pumpAndSettle();
  await tester.tap(find.text('儲存'));
  await tester.pumpAndSettle();
}

String? statusOf(String customerId) {
  for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
    if (customer['id'] == customerId) return customer['client_status'] as String?;
  }
  return null;
}

void main() {
  final DateTime today = DateTime(2026, 10, 15);

  group('填寫檢查', () {
    VisitResultDraft draft({String customerId = 'c1', String? result = 'positive', DateTime? visitedOn, String note = ''}) {
      return VisitResultDraft(projectId: 'p1', customerId: customerId, visitedOn: visitedOn ?? today, result: result, note: note);
    }

    test('客戶、結果必填；日期不能是未來；備註最多 200 字', () {
      expect(VisitResultService.validateDraft(draft(customerId: ''), today), '請選擇客戶');
      expect(VisitResultService.validateDraft(draft(result: null), today), '請選擇拜訪結果 ✔、△ 或 ✖');
      expect(VisitResultService.validateDraft(draft(visitedOn: DateTime(2026, 10, 16)), today), '拜訪日期不能是未來');
      expect(VisitResultService.validateDraft(draft(note: 'a' * 201), today), '備註最多 200 字');
      expect(VisitResultService.validateDraft(draft(), today), isNull);
    });

    test('今天帶著時間（例如下午 3 點）不算未來', () {
      expect(VisitResultService.validateDraft(draft(visitedOn: DateTime(2026, 10, 15, 15, 30)), DateTime(2026, 10, 15, 9)), isNull);
    });

    test('新的排前面：日期新的優先，同一天看建立時間', () {
      final VisitResult older = VisitResult(id: 'a', projectId: 'p', customerId: 'c', visitedOn: DateTime(2026, 10, 14), result: 'positive', createdAt: DateTime(2026, 10, 15, 9));
      final VisitResult sameDayEarly = VisitResult(id: 'b', projectId: 'p', customerId: 'c', visitedOn: today, result: 'positive', createdAt: DateTime(2026, 10, 15, 8));
      final VisitResult sameDayLate = VisitResult(id: 'c', projectId: 'p', customerId: 'c', visitedOn: today, result: 'positive', createdAt: DateTime(2026, 10, 15, 10));
      final List<VisitResult> list = [older, sameDayEarly, sameDayLate]..sort(VisitResult.compareNewestFirst);
      expect(list.map((result) => result.id).toList(), ['c', 'b', 'a']);
    });
  });

  testWidgets('連結的拜訪紀錄已刪除時顯示「此紀錄已刪除」', (WidgetTester tester) async {
    final VisitResult result = VisitResult.fromJson({
      'id': 'r1',
      'project_id': 'p1',
      'customer_id': 'c1',
      'visited_on': '2026-10-14',
      'result': 'considering',
      'note': '約下週',
      'visit_record_id': 'v1',
      'created_at': '2026-10-14T10:00:00Z',
      'visit_projects': {'title': '日常拜訪'},
      'customers': {'name': '王大明'},
      'visit_records': {'title': '10/14 王大明 保單說明', 'deleted_at': '2026-10-15T00:00:00Z'},
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisitResultListSection(
          results: [result],
          projects: const [],
          filterProjectId: null,
          hasMore: false,
          today: DateTime(2026, 10, 16),
          onFilterChanged: (_) {},
          onEdit: (_) {},
          onShowMore: () {},
        ),
      ),
    ));
    expect(find.text('🔗 此紀錄已刪除'), findsOneWidget);
    expect(find.text('10/14 王大明 保單說明'), findsNothing);
    expect(find.text('日常拜訪・約下週'), findsOneWidget);
  });

  group('記錄拜訪（離線預覽）', () {
    setUp(() {
      isOfflineMode = true;
      VisitProjectService.instance.resetOfflineForTest();
      VisitResultService.instance.resetOfflineForTest();
      OfflineDataStore.customers = [
        {'id': 'c1', 'name': '王大明', 'nickname': '', 'phone': '0912345678', 'deleted_at': null, 'client_status': null},
        {'id': 'c2', 'name': '陳美玲', 'nickname': '', 'phone': '0922333444', 'deleted_at': null, 'client_status': 'negative'},
      ];
    });

    testWidgets('記錄一筆：日常拜訪進度＋1、出現在紀錄、客戶狀態變成這次結果', (WidgetTester tester) async {
      await pumpPage(tester);
      await openTab(tester, '拜訪紀錄');
      expect(find.textContaining('還沒有拜訪結果'), findsOneWidget);

      await recordVisit(tester, customerName: '王大明', resultText: '✔ 有意願／已成交');

      expect(find.text('王大明'), findsOneWidget);
      expect(statusOf('c1'), 'positive');
      await openTab(tester, '總覽');
      expect(find.text('1 / 20 次'), findsOneWidget);
    });

    testWidgets('沒選結果時擋下並提示', (WidgetTester tester) async {
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(FilledButton, '記錄拜訪').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('選擇客戶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('王大明').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('請選擇拜訪結果 ✔、△ 或 ✖'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('修改結果後客戶狀態跟著改；刪除後變回原本沒有結果的狀態', (WidgetTester tester) async {
      await pumpPage(tester);
      await recordVisit(tester, customerName: '陳美玲', resultText: '△ 考慮中／待跟進');
      expect(statusOf('c2'), 'considering');
      await openTab(tester, '拜訪紀錄');

      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();
      expect(find.text('修改拜訪結果'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '✔ 有意願／已成交'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(statusOf('c2'), 'positive');

      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除').last);
      await tester.pumpAndSettle();
      expect(find.text('刪除這筆拜訪結果？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();
      // 結果全部刪光，狀態變未設定（資料庫觸發器同樣行為）
      expect(statusOf('c2'), isNull);
      expect(find.textContaining('還沒有拜訪結果'), findsOneWidget);
    });

    testWidgets('從專案卡片記錄：預設該專案，不在名單的客戶會提醒但一樣算進度', (WidgetTester tester) async {
      await VisitProjectService.instance.createProject(const VisitProjectDraft(
        title: '十月健檢',
        periodType: VisitProject.periodMonth,
        targetCount: 3,
        members: {'c1': '王大明'},
      ));
      await pumpPage(tester);
      // 第二張卡片（十月健檢）的「記錄拜訪」
      await tester.tap(find.widgetWithText(FilledButton, '記錄拜訪').at(2));
      await tester.pumpAndSettle();
      expect(find.text('十月健檢'), findsWidgets);
      await tester.tap(find.text('選擇客戶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('陳美玲').last);
      await tester.pumpAndSettle();
      expect(find.text('這位客戶不在專案名單裡，一樣會算進度'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '✖ 無意願／暫不考慮'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3 次'), findsOneWidget);
      expect(find.textContaining('還有 1 人沒拜訪：王大明'), findsOneWidget);
    });

    testWidgets('手機寬度：有紀錄時頁面不超出', (WidgetTester tester) async {
      await VisitResultService.instance.createResult(VisitResultDraft(
        projectId: 'offline-project-default',
        projectTitle: '日常拜訪',
        customerId: 'c1',
        customerName: '王大明',
        visitedOn: DateTime.now(),
        result: 'positive',
        note: '說明醫療險缺口，約下週帶建議書再談一次',
      ));
      await pumpPage(tester, size: const Size(375, 900));
      expect(tester.takeException(), isNull);
      await openTab(tester, '拜訪紀錄');
      expect(tester.takeException(), isNull);
      expect(find.text('拜訪結果紀錄'), findsOneWidget);
      expect(find.text('修改'), findsOneWidget);
    });
  });
}
