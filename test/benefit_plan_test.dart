import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/benefit_plan_service.dart';
import 'package:insurance_helper/widgets/benefit_plan_comparison.dart';

// 數字取自官方條款給付表（2026-10-27 盤點）
InsuranceBenefitPlan cathayPlan() {
  return InsuranceBenefitPlan.fromJson({
    'product_id': 'cathay-1',
    'plan_code': 'M20',
    'plan_order': 2,
    'benefit_type': 'deductible',
    'room_daily_limit': 2000,
    'hospital_expense_limit': 200000,
    'hospital_expense_includes_surgery': true,
    'outpatient_surgery_limit': 20000,
    'outpatient_surgery_deductible': 1000,
    'annual_total_limit': 750000,
    'daily_hospital_benefit': 2000,
  });
}

InsuranceBenefitPlan fubonPlan() {
  return InsuranceBenefitPlan.fromJson({
    'product_id': 'fubon-1',
    'plan_code': '計劃2',
    'plan_order': 2,
    'benefit_type': 'itemized',
    'room_daily_limit': 2000,
    'hospital_expense_limit': 200000,
    'surgery_limit': 60000,
    'outpatient_surgery_limit': 20000,
    'per_admission_total_limit': 300000,
    'annual_total_limit': 1000000,
    'daily_hospital_benefit': 2000,
  });
}

InsuranceBenefitPlan totalPlan() {
  return InsuranceBenefitPlan.fromJson({
    'product_id': 'fubon-2',
    'plan_code': '依投保單位',
    'benefit_type': 'total',
    'note': '不分項目，醫療費用都從累計總限額扣',
  });
}

void main() {
  group('實支實付計畫資料（D14）', () {
    test('金額格式：千分位、萬', () {
      expect(InsuranceBenefitPlan.formatAmount(1000000), '1,000,000');
      expect(InsuranceBenefitPlan.formatTenThousands(200000), '20 萬');
      expect(InsuranceBenefitPlan.formatTenThousands(15000), '1.5 萬');
      expect(InsuranceBenefitPlan.formatTenThousands(3000), '3,000');
    });

    test('計畫選單寫出重點限額；總額型註明', () {
      expect(fubonPlan().optionLabel, '計劃2（病房 2,000｜住院醫療 20 萬）');
      expect(totalPlan().optionLabel, '依投保單位（總額型）');
    });

    test('類型名稱', () {
      expect(fubonPlan().typeLabel, '分項限額型');
      expect(cathayPlan().typeLabel, '自負額型');
      expect(totalPlan().typeLabel, '總額型');
    });
  });

  group('比較表每一格的文字', () {
    test('國泰：住院醫療費用含手術，住院手術顯示「含在住院醫療費用」', () {
      final InsuranceBenefitPlan plan = cathayPlan();
      expect(benefitRowText('每日病房', plan), '2,000');
      expect(benefitRowText('住院醫療費用', plan), '200,000（含手術）');
      expect(benefitRowText('住院手術', plan), '— 含在住院醫療費用');
      expect(benefitRowText('總限額', plan), '每年 750,000');
      expect(benefitRowText('自負額', plan), '門診手術 1,000');
      expect(benefitRowText('說明', plan), '—');
    });

    test('富邦：手術分開列，總限額有每次住院與每年', () {
      final InsuranceBenefitPlan plan = fubonPlan();
      expect(benefitRowText('住院醫療費用', plan), '200,000');
      expect(benefitRowText('住院手術', plan), '60,000');
      expect(benefitRowText('總限額', plan), '每次住院 300,000／每年 1,000,000');
      expect(benefitRowText('自負額', plan), '—');
      expect(benefitRowText('住院日額', plan), '2,000');
    });

    test('總額型：分項目的列顯示「不分項目」', () {
      final InsuranceBenefitPlan plan = totalPlan();
      expect(benefitRowText('類型', plan), '總額型');
      expect(benefitRowText('每日病房', plan), notItemizedText);
      expect(benefitRowText('住院手術', plan), notItemizedText);
      expect(benefitRowText('總限額', plan), '累計總限額（依投保單位）');
      expect(benefitRowText('說明', plan), contains('累計總限額'));
    });

    test('沒有限額表的商品', () {
      expect(benefitRowText('類型', null), notReimbursementText);
      expect(benefitRowText('每日病房', null), '—');
    });
  });

  group('計畫選單', () {
    testWidgets('多個計畫：選單列出重點限額，選了會回傳位置', (WidgetTester tester) async {
      int selected = 0;
      final List<InsuranceBenefitPlan> plans = [
        InsuranceBenefitPlan.fromJson({'product_id': 'x', 'plan_code': '計劃1', 'room_daily_limit': 1000, 'hospital_expense_limit': 100000}),
        fubonPlan(),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: BenefitPlanSelector(plans: plans, selectedIndex: 0, onChanged: (int index) => selected = index),
          ),
        ),
      ));
      expect(find.text('計劃1（病房 1,000｜住院醫療 10 萬）'), findsOneWidget);
      await tester.tap(find.text('計劃1（病房 1,000｜住院醫療 10 萬）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('計劃2（病房 2,000｜住院醫療 20 萬）').last);
      await tester.pumpAndSettle();
      expect(selected, 1);
    });

    testWidgets('只有一個計畫：直接顯示文字', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BenefitPlanSelector(plans: [totalPlan()], selectedIndex: 0, onChanged: (_) {})),
      ));
      expect(find.text('計畫：依投保單位（總額型）'), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsNothing);
    });
  });
}
