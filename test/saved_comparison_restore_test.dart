import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/saved_comparison.dart';
import 'package:insurance_helper/screens/policy_comparison_screen.dart';
import 'package:insurance_helper/services/benefit_trial_calculator.dart';
import 'package:insurance_helper/services/insurance_product_service.dart';
import 'package:insurance_helper/services/scenario/claim_scenario.dart';
import 'package:insurance_helper/theme/app_theme.dart';
import 'package:insurance_helper/widgets/benefit_trial_inputs.dart';
import 'package:insurance_helper/widgets/saved_comparison/saved_comparison_update_panel.dart';

InsuranceProduct buildProduct(String id) {
  return InsuranceProduct.fromJson({
    'id': id,
    'company_code': 'fubon',
    'company_name': '富邦人壽',
    'product_code': id.toUpperCase(),
    'product_name': '測試商品 $id',
    'product_kind': 'main',
    'insurance_type': 'medical',
    'source_category': '健康保險',
    'source_url': 'https://example.com',
    'last_seen_at': '2026-11-09T00:00:00Z',
  });
}

SavedComparison buildComparison({String name = '醫療1'}) {
  return SavedComparison(
    id: 'comparison-1',
    customerId: 'customer-1',
    name: name,
    scenario: const ClaimScenarioInput(hospitalDays: 9),
    items: const [
      SavedComparisonItem(productId: 'p1', copies: 2, annualPremium: 12000),
      SavedComparisonItem(productId: 'p2'),
    ],
    updatedAt: DateTime.utc(2026, 11, 10),
  );
}

Future<void> pumpUpdatePanel(
  WidgetTester tester, {
  required UpdateComparisonAction updateComparison,
  required SaveAsNewComparisonAction saveAsNewComparison,
  required ValueChanged<SavedComparison> onSavedAsNew,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(AppThemeColors.deepSea),
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: SavedComparisonUpdatePanel(
          comparison: buildComparison(),
          customerName: '王大明',
          currentScenario: () => const ClaimScenarioInput(hospitalDays: 3),
          currentItems: () => buildComparison().items,
          onSavedAsNew: onSavedAsNew,
          updateComparison: updateComparison,
          saveAsNewComparison: saveAsNewComparison,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('找得到比較裡的商品，找不到回傳 null', () {
    final SavedComparison comparison = buildComparison();
    expect(comparison.itemFor('p1')?.copies, 2);
    expect(comparison.itemFor('沒有這款'), isNull);
  });

  testWidgets('試算欄帶入存過的數字，保額顯示回萬元', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(AppThemeColors.deepSea),
      home: Scaffold(
        body: BenefitTrialPanel(
          fields: const BenefitTrialFields(needsCoverageAmount: true, needsDailyAmount: true, needsUnits: true),
          onChanged: (BenefitTrialInput input) {},
          initialInput: const BenefitTrialInput(coverageAmount: 1000000, dailyAmount: 2000, units: 3, annualPremium: 12000),
        ),
      ),
    ));
    expect(find.widgetWithText(TextField, '100'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2000'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextField, '12000'), findsOneWidget);
  });

  testWidgets('比較頁打開舊比較：情境數字還原，存檔框變成更新／另存', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: PolicyComparisonScreen(
        initialProducts: [buildProduct('p1'), buildProduct('p2')],
        savedComparison: buildComparison(),
        customerName: '王大明',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '9'), findsOneWidget);
    expect(find.text('王大明 的比較'), findsOneWidget);
    expect(find.text('醫療1'), findsOneWidget);
    expect(find.text('更新這筆'), findsOneWidget);
    expect(find.text('另存新的'), findsOneWidget);
    expect(find.text('把這次比較存到客戶'), findsNothing);
  });

  testWidgets('更新這筆：用目前的數字更新原本那筆', (WidgetTester tester) async {
    String? updatedId;
    ClaimScenarioInput? updatedScenario;
    await pumpUpdatePanel(
      tester,
      updateComparison: (comparisonId, scenario, items) async {
        updatedId = comparisonId;
        updatedScenario = scenario;
      },
      saveAsNewComparison: (customerId, name, scenario, items) async => buildComparison(name: name),
      onSavedAsNew: (SavedComparison comparison) {},
    );
    await tester.tap(find.text('更新這筆'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(updatedId, 'comparison-1');
    expect(updatedScenario?.hospitalDays, 3);
  });

  testWidgets('另存新的：問名稱、存在同一位客戶下，並換成新的那筆', (WidgetTester tester) async {
    String? savedCustomerId;
    String? savedName;
    SavedComparison? openedAfterSave;
    await pumpUpdatePanel(
      tester,
      updateComparison: (comparisonId, scenario, items) async {},
      saveAsNewComparison: (customerId, name, scenario, items) async {
        savedCustomerId = customerId;
        savedName = name;
        return buildComparison(name: name);
      },
      onSavedAsNew: (SavedComparison comparison) => openedAfterSave = comparison,
    );
    await tester.tap(find.text('另存新的'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 醫療2 ');
    await tester.tap(find.text('另存'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(savedCustomerId, 'customer-1');
    expect(savedName, '醫療2');
    expect(openedAfterSave?.name, '醫療2');
  });

  testWidgets('另存新的按取消就不存', (WidgetTester tester) async {
    bool isSaved = false;
    await pumpUpdatePanel(
      tester,
      updateComparison: (comparisonId, scenario, items) async {},
      saveAsNewComparison: (customerId, name, scenario, items) async {
        isSaved = true;
        return buildComparison(name: name);
      },
      onSavedAsNew: (SavedComparison comparison) {},
    );
    await tester.tap(find.text('另存新的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(isSaved, isFalse);
  });
}
