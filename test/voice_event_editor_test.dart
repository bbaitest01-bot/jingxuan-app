import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/widgets/schedule_event_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScheduleEvent buildEvent(String id) {
  final DateTime start = DateTime(2026, 10, 15, 14, 0);
  return ScheduleEvent(
    id: id,
    profileId: 'user-1',
    title: '和王小姐討論保單',
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
  );
}

Future<void> pumpEditor(WidgetTester tester, ScheduleEvent event) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ScheduleEventDialog(initialDate: event.startAt, eventToEdit: event, isBottomSheet: true),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    isOfflineMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('語音帶入的行程（還沒有編號）是「新增」：沒有刪除按鈕，內容已填好', (WidgetTester tester) async {
    await pumpEditor(tester, buildEvent(''));
    // 刪除按鈕的圖示（文字會依語系不同，所以用圖示判斷）
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('和王小姐討論保單'), findsOneWidget);
  });

  testWidgets('已存在的行程是「編輯」：有刪除按鈕', (WidgetTester tester) async {
    await pumpEditor(tester, buildEvent('event-1'));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
