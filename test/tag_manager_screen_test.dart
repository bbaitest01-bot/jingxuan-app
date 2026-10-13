import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/screens/tag_manager_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // 離線模式：標籤存在模擬的瀏覽器本機，不連資料庫
    isOfflineMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('點選大分類 → 按鉛筆 → 刪除此資料夾 → 確認刪除，大分類消失', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: TagManagerScreen()));
    await tester.pumpAndSettle();

    // 點「生活興趣」選取它，再點一次（點在鉛筆上）打開編輯視窗
    await tester.tap(find.text('生活興趣'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ChoiceChip), matching: find.byIcon(Icons.edit_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('刪除此資料夾'), findsOneWidget);

    await tester.tap(find.text('刪除此資料夾'));
    await tester.pumpAndSettle();
    expect(find.text('確認刪除大分類？'), findsOneWidget);

    await tester.tap(find.text('確認刪除'));
    await tester.pumpAndSettle();
    expect(find.text('生活興趣'), findsNothing);

    // 讓提示橫幅的計時器跑完
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('分類標題旁的「編輯／刪除分類」按鈕可以打開編輯視窗', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: TagManagerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('編輯／刪除分類'));
    await tester.pumpAndSettle();
    expect(find.text('刪除此資料夾'), findsOneWidget);
    expect(find.text('儲存修改'), findsOneWidget);
  });
}
