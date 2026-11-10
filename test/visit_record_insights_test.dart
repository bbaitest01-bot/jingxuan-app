import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/models/visit_record_insights.dart';
import 'package:insurance_helper/screens/visit_records/visit_record_insights_panel.dart';

Map<String, dynamic> buildDraftJson({
  String id = 'd1',
  String title = '與客戶再次見面',
  dynamic date = '2026-11-20',
  dynamic time = '15:00',
  String state = 'pending',
}) {
  return {
    'draft_id': id,
    'title': title,
    'date': date,
    'time': time,
    'location': '咖啡廳',
    'source_quote': '11月20號下午三點再跟他約一次',
    'draft_state': state,
  };
}

VisitRecord buildRecord({dynamic keyPoints, dynamic drafts, String status = 'done'}) {
  return VisitRecord.fromJson({
    'id': 'r1',
    'profile_id': 'u1',
    'title': '測試',
    'raw_transcript': '今天去拜訪林先生',
    'status': status,
    'processing_started_at': status == 'processing' ? DateTime.now().toUtc().toIso8601String() : null,
    'created_at': '2026-11-10T07:00:00Z',
    'updated_at': '2026-11-10T07:00:00Z',
    'key_points': keyPoints,
    'follow_up_drafts': drafts,
  });
}

Future<void> pumpPanel(
  WidgetTester tester,
  VisitRecord record, {
  ValueChanged<VisitFollowUpDraft>? onCreateEvent,
  ValueChanged<VisitFollowUpDraft>? onDismiss,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: VisitRecordInsightsPanel(
          record: record,
          onCreateEvent: onCreateEvent ?? (_) {},
          onDismiss: onDismiss ?? (_) {},
        ),
      ),
    ),
  ));
}

void main() {
  group('AI 資料的防護', () {
    test('重點形狀不對時當作沒有；清單裡的非文字會略過', () {
      expect(VisitKeyPoints.tryParse('不是物件'), isNull);
      expect(VisitKeyPoints.tryParse([1, 2]), isNull);
      final VisitKeyPoints? points = VisitKeyPoints.tryParse({
        'interviewee': 123,
        'needs': ['實支實付', 5, ' '],
        'health_concerns': '不是清單',
      });
      expect(points?.interviewee, '');
      expect(points?.needs, ['實支實付']);
      expect(points?.healthConcerns, isEmpty);
    });

    test('待辦沒有編號或標題就丟棄；不是清單時回傳空的', () {
      expect(VisitFollowUpDraft.parseList('不是清單'), isEmpty);
      final List<VisitFollowUpDraft> drafts = VisitFollowUpDraft.parseList([
        buildDraftJson(),
        {'draft_id': 'd2'},
        {'title': '沒有編號'},
        '不是物件',
      ]);
      expect(drafts.length, 1);
    });

    test('不存在的日期與時間當作沒有', () {
      final VisitFollowUpDraft? badDate = VisitFollowUpDraft.tryParse(buildDraftJson(date: '2026-02-30', time: '25:00'));
      expect(badDate?.date, isNull);
      expect(badDate?.hour, isNull);
      expect(badDate?.whenLabel, '日期未定');
    });

    test('存回資料庫的格式不變', () {
      final Map<String, dynamic> original = buildDraftJson();
      expect(VisitFollowUpDraft.tryParse(original)?.toJson(), original);
    });
  });

  group('帶入行程視窗的內容', () {
    final DateTime now = DateTime(2026, 11, 10, 9, 30);

    test('有日期時間：照草稿帶入，編號空白代表新增', () {
      final ScheduleEvent event = VisitFollowUpDraft.tryParse(buildDraftJson())!.buildScheduleEvent(now: now, customerId: 'c1');
      expect(event.id, '');
      expect(event.startAt, DateTime(2026, 11, 20, 15));
      expect(event.endAt, DateTime(2026, 11, 20, 16));
      expect(event.customerId, 'c1');
      expect(event.eventType, 'customer_visit');
      expect(event.description, contains('11月20號'));
    });

    test('有日期沒時間：預設 10 點', () {
      final ScheduleEvent event = VisitFollowUpDraft.tryParse(buildDraftJson(time: null))!.buildScheduleEvent(now: now);
      expect(event.startAt, DateTime(2026, 11, 20, 10));
      expect(event.eventType, 'follow_up');
    });

    test('沒有日期：預設下一個整點', () {
      final ScheduleEvent event = VisitFollowUpDraft.tryParse(buildDraftJson(date: null, time: null))!.buildScheduleEvent(now: now);
      expect(event.startAt, DateTime(2026, 11, 10, 10));
    });
  });

  group('單篇頁區塊', () {
    const Map<String, dynamic> keyPoints = {
      'interviewee': '林先生',
      'needs': ['實支實付'],
      'next_steps': ['做保障缺口表'],
    };

    testWidgets('沒有重點也沒有草稿：什麼都不顯示', (WidgetTester tester) async {
      await pumpPanel(tester, buildRecord());
      expect(find.text('重點'), findsNothing);
      expect(find.text('待辦草稿'), findsNothing);
    });

    testWidgets('整理中不顯示上一次的結果', (WidgetTester tester) async {
      await pumpPanel(tester, buildRecord(keyPoints: keyPoints, drafts: [buildDraftJson()], status: 'processing'));
      expect(find.text('重點'), findsNothing);
    });

    testWidgets('顯示重點與待辦；按鈕會帶回該筆草稿', (WidgetTester tester) async {
      VisitFollowUpDraft? created;
      VisitFollowUpDraft? dismissed;
      await pumpPanel(
        tester,
        buildRecord(keyPoints: keyPoints, drafts: [buildDraftJson()]),
        onCreateEvent: (VisitFollowUpDraft draft) => created = draft,
        onDismiss: (VisitFollowUpDraft draft) => dismissed = draft,
      );
      expect(find.text('林先生'), findsOneWidget);
      expect(find.text('11/20 15:00'), findsOneWidget);
      await tester.tap(find.text('建立行程'));
      await tester.tap(find.text('略過'));
      expect(created?.draftId, 'd1');
      expect(dismissed?.draftId, 'd1');
    });

    testWidgets('已建立不能再按；已略過不顯示', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        buildRecord(drafts: [buildDraftJson(state: 'accepted'), buildDraftJson(id: 'd2', title: '已略過的事', state: 'dismissed')]),
      );
      expect(find.textContaining('已建立行程'), findsOneWidget);
      expect(find.text('建立行程'), findsNothing);
      expect(find.text('已略過的事'), findsNothing);
    });

    testWidgets('手機寬度不超出畫面', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPanel(tester, buildRecord(keyPoints: keyPoints, drafts: [buildDraftJson()]));
      expect(tester.takeException(), isNull);
    });
  });
}
