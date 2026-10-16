import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/screens/visit_records/visit_record_organize_banner.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

VisitRecord buildRecord({required String status, DateTime? startedAt, String? reason}) {
  return VisitRecord.fromJson({
    'id': 'r1',
    'profile_id': 'u1',
    'title': '2026/10/16 15:30 拜訪紀錄',
    'raw_transcript': '今天去拜訪陳媽媽',
    'status': status,
    'failure_reason': reason,
    'processing_started_at': startedAt?.toUtc().toIso8601String(),
    'created_at': '2026-10-16T07:00:00Z',
    'updated_at': '2026-10-16T07:00:00Z',
  });
}

Future<void> pumpBanner(WidgetTester tester, VisitRecord record, {VoidCallback? onRetry}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: VisitRecordOrganizeBanner(record: record, isRequesting: false, onRetry: onRetry ?? () {}),
    ),
  ));
}

void main() {
  group('整理中卡住的判斷（超過 5 分鐘）', () {
    final DateTime now = DateTime(2026, 10, 16, 15, 30);

    test('剛開始整理不算卡住；超過 5 分鐘算失敗', () {
      final VisitRecord fresh = buildRecord(status: 'processing', startedAt: now.subtract(const Duration(minutes: 1)));
      final VisitRecord stuck = buildRecord(status: 'processing', startedAt: now.subtract(const Duration(minutes: 6)));
      expect(fresh.isOrganizeStale(now), isFalse);
      expect(fresh.isOrganizeFailed(now), isFalse);
      expect(stuck.isOrganizeStale(now), isTrue);
      expect(stuck.isOrganizeFailed(now), isTrue);
    });

    test('整理中卻沒有開始時間也當作卡住；其他狀態不會卡住', () {
      expect(buildRecord(status: 'processing').isOrganizeStale(now), isTrue);
      expect(buildRecord(status: 'done', startedAt: now.subtract(const Duration(hours: 1))).isOrganizeStale(now), isFalse);
      expect(buildRecord(status: 'failed').isOrganizeFailed(now), isTrue);
    });
  });

  group('單篇頁的整理狀態', () {
    testWidgets('整理中：顯示轉圈與說明', (WidgetTester tester) async {
      await pumpBanner(tester, buildRecord(status: 'processing', startedAt: DateTime.now()));
      expect(find.textContaining('AI 整理中'), findsOneWidget);
      expect(find.text('重新整理'), findsNothing);
    });

    testWidgets('失敗：顯示原因與「重新整理」，按了會呼叫', (WidgetTester tester) async {
      bool retried = false;
      await pumpBanner(tester, buildRecord(status: 'failed', reason: '整理逾時（超過 60 秒沒有回應）'), onRetry: () => retried = true);
      expect(find.textContaining('整理逾時'), findsOneWidget);
      await tester.tap(find.text('重新整理'));
      expect(retried, isTrue);
    });

    testWidgets('整理中卡住超過 5 分鐘：當作失敗', (WidgetTester tester) async {
      await pumpBanner(tester, buildRecord(status: 'processing', startedAt: DateTime.now().subtract(const Duration(minutes: 10))));
      expect(find.textContaining('超過 5 分鐘沒有完成'), findsOneWidget);
      expect(find.text('重新整理'), findsOneWidget);
    });

    testWidgets('完成：一行說明；打字建立（尚未整理）：什麼都不顯示', (WidgetTester tester) async {
      await pumpBanner(tester, buildRecord(status: 'done'));
      expect(find.textContaining('已由 AI 整理'), findsOneWidget);
      await pumpBanner(tester, buildRecord(status: 'raw'));
      expect(find.textContaining('AI'), findsNothing);
    });
  });

  group('離線預覽', () {
    setUp(() {
      isOfflineMode = true;
      VisitRecordService.instance.clearOfflineRecordsForTest();
    });

    test('錄音建立的紀錄在離線預覽不會進入整理中；要求整理會提示無法使用', () async {
      final VisitRecord record = await VisitRecordService.instance.createRecord(
        title: '測試',
        rawTranscript: '今天去拜訪陳媽媽',
        startOrganizing: true,
      );
      expect(record.status, VisitRecord.statusRaw);
      expect(() => VisitRecordService.instance.requestOrganize(record.id), throwsException);
    });
  });
}
