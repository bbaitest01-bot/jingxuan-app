import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_chart.dart';
import 'package:insurance_helper/models/visit_project.dart';
import 'package:insurance_helper/models/visit_result.dart';
import 'package:insurance_helper/screens/visit_projects/visit_chart_card.dart';
import 'package:insurance_helper/screens/visit_projects/visit_projects_page.dart';
import 'package:insurance_helper/services/visit_pending_service.dart';
import 'package:insurance_helper/services/visit_project_service.dart';
import 'package:insurance_helper/services/visit_result_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

VisitChartPoint point(DateTime day, String result, {String projectId = 'p1', List<String> tags = const []}) {
  return VisitChartPoint(visitedOn: day, result: result, projectId: projectId, customerTags: tags);
}

void main() {
  // 2026-10-15 是週四
  final DateTime today = DateTime(2026, 10, 15);

  group('期間與格子', () {
    test('週：週一到週日，今天之後是「還沒到」', () {
      final VisitChartPeriod period = buildVisitChartPeriod(VisitChartRange.week, 0, today);
      expect(period.buckets.length, 7);
      expect(period.from, DateTime(2026, 10, 12));
      expect(period.to, DateTime(2026, 10, 18));
      expect(period.title, '本週 10/12～10/18');
      expect(period.buckets[3].isFuture, isFalse); // 週四＝今天
      expect(period.buckets[4].isFuture, isTrue);
      expect(period.buckets[0].fullLabel, '10/12（一）');
    });

    test('月：上一期是 9 月，30 格，全部已經過去', () {
      final VisitChartPeriod period = buildVisitChartPeriod(VisitChartRange.month, -1, today);
      expect(period.title, '2026 年 9 月');
      expect(period.buckets.length, 30);
      expect(period.buckets.every((bucket) => !bucket.isFuture), isTrue);
    });

    test('年：12 個月，11、12 月還沒到；跨年的上一週也算得對', () {
      final VisitChartPeriod year = buildVisitChartPeriod(VisitChartRange.year, 0, today);
      expect(year.buckets.length, 12);
      expect(year.buckets[9].isFuture, isFalse);
      expect(year.buckets[10].isFuture, isTrue);
      final VisitChartPeriod newYearWeek = buildVisitChartPeriod(VisitChartRange.week, -1, DateTime(2027, 1, 6));
      expect(newYearWeek.from, DateTime(2026, 12, 28));
    });
  });

  group('每條線的數字', () {
    final VisitChartPeriod week = buildVisitChartPeriod(VisitChartRange.week, 0, today);
    final List<VisitChartPoint> points = [
      point(DateTime(2026, 10, 12), VisitResult.resultPositive, tags: ['轉介紹']),
      point(DateTime(2026, 10, 12), VisitResult.resultConsidering, projectId: 'p2'),
      point(DateTime(2026, 10, 14), VisitResult.resultNegative, tags: ['轉介紹', '高爾夫']),
      point(DateTime(2026, 10, 5), VisitResult.resultPositive), // 上週，不算
    ];

    test('按結果：✔△✖ 與總數；還沒到的格子是空的', () {
      final List<VisitChartSeries> series = buildVisitChartSeries(
        mode: VisitChartMode.byResult,
        range: VisitChartRange.week,
        period: week,
        points: points,
        projects: const [],
      );
      expect(series.map((line) => line.id).toList(), ['positive', 'considering', 'negative', 'total']);
      expect(series.last.values, [2, 0, 1, 0, null, null, null]);
      expect(series.first.total, 1);
    });

    test('按專案：每個專案一條線', () {
      final List<VisitProject> projects = [
        VisitProject(id: 'p1', title: '日常拜訪', periodType: 'month', targetCount: 20, createdAt: today),
        VisitProject(id: 'p2', title: '十月健檢', periodType: 'month', targetCount: 5, createdAt: today),
      ];
      final List<VisitChartSeries> series = buildVisitChartSeries(
        mode: VisitChartMode.byProject,
        range: VisitChartRange.week,
        period: week,
        points: points,
        projects: projects,
      );
      expect(series.map((line) => line.total).toList(), [2, 1]);
    });

    test('按標籤：只算有該標籤的客戶', () {
      final List<VisitChartSeries> series = buildVisitChartSeries(
        mode: VisitChartMode.byTag,
        range: VisitChartRange.week,
        period: week,
        points: points,
        projects: const [],
        tag: '轉介紹',
      );
      expect(series.last.total, 2);
      expect(series.first.total, 1); // ✔ 一次
    });

    test('年：依月份累計', () {
      final VisitChartPeriod year = buildVisitChartPeriod(VisitChartRange.year, 0, today);
      final List<VisitChartSeries> series = buildVisitChartSeries(
        mode: VisitChartMode.byResult,
        range: VisitChartRange.year,
        period: year,
        points: points,
        projects: const [],
      );
      expect(series.last.values[9], 4);
      expect(series.last.values[11], isNull);
    });

    test('y 軸最大值取整齊數字', () {
      expect(niceChartMax(0), 4);
      expect(niceChartMax(3), 4);
      expect(niceChartMax(7), 8);
      expect(niceChartMax(13), 20);
      expect(niceChartMax(41), 80);
    });
  });

  group('圖表畫面（離線預覽）', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      isOfflineMode = true;
      VisitProjectService.instance.resetOfflineForTest();
      VisitResultService.instance.resetOfflineForTest();
      VisitPendingService.instance.resetOfflineForTest();
      OfflineDataStore.customers = [
        {'id': 'c1', 'name': '王大明', 'tags': ['轉介紹'], 'deleted_at': null, 'client_status': null},
      ];
      OfflineDataStore.scheduleEvents = [];
    });

    testWidgets('專案拜訪頁最上方有圖表；切換週月年與看法不出錯', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await VisitResultService.instance.createResult(VisitResultDraft(
        projectId: 'offline-project-default',
        projectTitle: '日常拜訪',
        customerId: 'c1',
        customerName: '王大明',
        visitedOn: DateTime.now(),
        result: VisitResult.resultPositive,
      ));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VisitProjectsPage())));
      await tester.pumpAndSettle();

      expect(find.byType(VisitChartCard), findsOneWidget);
      expect(find.text('拜訪成效'), findsOneWidget);
      expect(find.textContaining('這一期總共 1 次', findRichText: true), findsOneWidget);

      await tester.tap(find.text('週'));
      await tester.pumpAndSettle();
      expect(find.textContaining('本週', findRichText: true), findsOneWidget);
      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('按專案'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('上一期'));
      await tester.pumpAndSettle();
      expect(find.textContaining('這一期總共 0 次', findRichText: true), findsNothing); // 按專案沒有總數那一行
      expect(tester.takeException(), isNull);
    });

    testWidgets('手機寬度：圖表與切換按鈕不超出', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VisitProjectsPage())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('按標籤'), findsOneWidget);
    });
  });
}
