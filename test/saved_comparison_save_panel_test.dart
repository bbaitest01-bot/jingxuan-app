import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/saved_comparison.dart';
import 'package:insurance_helper/services/saved_comparison_service.dart';
import 'package:insurance_helper/services/scenario/claim_scenario.dart';
import 'package:insurance_helper/theme/app_theme.dart';
import 'package:insurance_helper/widgets/saved_comparison/saved_comparison_save_panel.dart';

final List<Map<String, dynamic>> testCustomers = [
  {'id': 'c1', 'name': '王大明', 'phone': '0900-000-101', 'profile_id': 'agent-1'},
  {'id': 'c2', 'name': '吳雅婷', 'nickname': '雅婷', 'phone': '', 'profile_id': 'agent-2'},
];

const List<SavedComparisonItem> testItems = [
  SavedComparisonItem(productId: 'p1', copies: 2),
  SavedComparisonItem(productId: 'p2'),
];

Future<void> pumpPanel(WidgetTester tester, SaveComparisonAction saveComparison) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(AppThemeColors.deepSea),
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: SavedComparisonSavePanel(
          currentScenario: () => const ClaimScenarioInput(hospitalDays: 9),
          currentItems: () => testItems,
          loadCustomers: () async => testCustomers,
          saveComparison: saveComparison,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> chooseFirstCustomer(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).first);
  await tester.enterText(find.byType(TextField).first, '王大');
  await tester.pumpAndSettle();
  await tester.tap(find.text('王大明・0900-000-101').last);
  await tester.pumpAndSettle();
}

Future<void> pressSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '存到客戶'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  test('搜尋姓名、暱稱、電話都找得到', () {
    expect(SavedComparisonSavePanel.filterCustomers(testCustomers, '').length, 2);
    expect(SavedComparisonSavePanel.filterCustomers(testCustomers, '大明').first['id'], 'c1');
    expect(SavedComparisonSavePanel.filterCustomers(testCustomers, '雅婷').first['id'], 'c2');
    expect(SavedComparisonSavePanel.filterCustomers(testCustomers, '000-101').first['id'], 'c1');
    expect(SavedComparisonSavePanel.filterCustomers(testCustomers, '沒有這個人'), isEmpty);
  });

  test('只留下自己名下的客戶', () {
    final List<Map<String, dynamic>> ownCustomers = SavedComparisonService.keepOwnCustomers(testCustomers, 'agent-1');
    expect(ownCustomers.length, 1);
    expect(ownCustomers.first['id'], 'c1');
    expect(SavedComparisonService.keepOwnCustomers(testCustomers, null), isEmpty);
  });

  testWidgets('沒選客戶不能存', (WidgetTester tester) async {
    bool isSaved = false;
    await pumpPanel(tester, (customerId, name, scenario, items) async => isSaved = true);
    await tester.enterText(find.byType(TextField).last, '醫療1');
    await pressSave(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(isSaved, isFalse);
  });

  testWidgets('選客戶、命名後，把目前的情境和商品一起存，名稱清空', (WidgetTester tester) async {
    String? savedCustomerId;
    String? savedName;
    ClaimScenarioInput? savedScenario;
    List<SavedComparisonItem>? savedItems;
    await pumpPanel(tester, (customerId, name, scenario, items) async {
      savedCustomerId = customerId;
      savedName = name;
      savedScenario = scenario;
      savedItems = items;
    });
    await chooseFirstCustomer(tester);
    await tester.enterText(find.byType(TextField).last, ' 醫療1 ');
    await pressSave(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(savedCustomerId, 'c1');
    expect(savedName, '醫療1');
    expect(savedScenario?.hospitalDays, 9);
    expect(savedItems?.first.copies, 2);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller?.text, '');
  });

  testWidgets('選好後又改客戶欄位，就要重選', (WidgetTester tester) async {
    bool isSaved = false;
    await pumpPanel(tester, (customerId, name, scenario, items) async => isSaved = true);
    await chooseFirstCustomer(tester);
    await tester.enterText(find.byType(TextField).first, '王大明改');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '醫療1');
    await pressSave(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(isSaved, isFalse);
  });

  testWidgets('同名時保留輸入的名稱，讓業務員改', (WidgetTester tester) async {
    await pumpPanel(tester, (customerId, name, scenario, items) async {
      throw const SavedComparisonException('這位客戶已經有同名的比較，請換一個名稱');
    });
    await chooseFirstCustomer(tester);
    await tester.enterText(find.byType(TextField).last, '醫療1');
    await pressSave(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.widget<TextField>(find.byType(TextField).last).controller?.text, '醫療1');
  });

  testWidgets('窄畫面上下排，寬畫面並排', (WidgetTester tester) async {
    const Key scenarioKey = Key('scenario');
    const Key saveKey = Key('save');
    Future<void> pumpWidth(double width) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const ScenarioWithSavePanelLayout(
                scenarioPanel: SizedBox(key: scenarioKey, width: 400, height: 50),
                savePanel: SizedBox(key: saveKey, height: 50),
              ),
            ),
          ),
        ),
      ));
    }

    await pumpWidth(1000);
    expect(tester.getTopLeft(find.byKey(saveKey)).dy, tester.getTopLeft(find.byKey(scenarioKey)).dy);
    await pumpWidth(400);
    expect(tester.getTopLeft(find.byKey(saveKey)).dy, greaterThan(tester.getTopLeft(find.byKey(scenarioKey)).dy));
  });
}
