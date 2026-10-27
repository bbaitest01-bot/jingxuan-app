import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/benefit_plan_service.dart';
import 'package:insurance_helper/services/coverage_check_service.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/widgets/coverage_check/customer_coverage_check_section.dart';

CustomerEnrolledPolicy buildPolicy(String id, String productId,
    {String status = 'active', int? amount, String? planId, String? category, String? planText}) {
  return CustomerEnrolledPolicy.fromJson({
    'id': id,
    'customer_id': 'c1',
    'policy_clause_id': productId,
    'product_name': '商品$id',
    'company_name': '國泰人壽',
    'status': status,
    'coverage_amount': amount,
    'benefit_plan_id': planId,
    'coverage_category': category,
    'plan_or_amount': planText,
  });
}

InsuranceBenefitPlan plan(String id, String code, int room, int hospital) {
  return InsuranceBenefitPlan.fromJson({
    'id': id, 'product_id': 'reimb', 'plan_code': code, 'room_daily_limit': room, 'hospital_expense_limit': hospital,
  });
}

void main() {
  group('保額文字轉數字', () {
    test('萬、千分位、日額', () {
      expect(CoverageCheckService.parseAmount('50 萬元'), 500000);
      expect(CoverageCheckService.parseAmount('保險金額 300 萬元'), 3000000);
      expect(CoverageCheckService.parseAmount('新臺幣 3,000,000 元'), 3000000);
      expect(CoverageCheckService.parseAmount('日額 2,000 元'), 2000);
      expect(CoverageCheckService.parseAmount('1.5萬'), 15000);
    });

    test('外幣、只有計畫名稱時不猜', () {
      expect(CoverageCheckService.parseAmount('保險金額 USD 100,000'), isNull);
      expect(CoverageCheckService.parseAmount('計畫三'), isNull);
      expect(CoverageCheckService.parseAmount(null), isNull);
    });
  });

  group('保單上的計畫對到限額表', () {
    final List<InsuranceBenefitPlan> fubon = [plan('p1', '計劃1', 1000, 100000), plan('p2', '計劃2', 2000, 200000), plan('p3', '計劃3', 3000, 300000)];
    test('國字、計畫／計劃寫法不同也對得到', () {
      expect(CoverageCheckService.matchPlan('計畫三', fubon)?.id, 'p3');
      expect(CoverageCheckService.matchPlan('計劃 2', fubon)?.id, 'p2');
      expect(CoverageCheckService.matchPlan('B型', [plan('a', 'A型', 3000, 0), plan('b', 'B型', 2000, 0)])?.id, 'b');
      expect(CoverageCheckService.matchPlan('M20', [plan('m', 'M20', 2000, 0)])?.id, 'm');
    });
    test('對不到回傳 null', () {
      expect(CoverageCheckService.matchPlan('計畫五', fubon), isNull);
      expect(CoverageCheckService.matchPlan('', fubon), isNull);
    });
  });

  group('健檢加總', () {
    final Map<String, String?> categories = {'life1': 'life', 'cancer1': 'cancer', 'reimb': 'reimbursement', 'rider': 'none', 'unknown': null};
    final Map<String, InsuranceBenefitPlan> plans = {'p2': plan('p2', '計劃2', 2000, 200000)};

    test('有效保單依類別加總；失效、不列入的不算；沒填保額、看不出類別分開數', () {
      final CoverageCheckResult result = CoverageCheckService.calculate(
        policies: [
          buildPolicy('1', 'life1', amount: 1000000),
          buildPolicy('2', 'life1', amount: 500000),
          buildPolicy('3', 'life1', amount: 9000000, status: 'lapsed'),
          buildPolicy('4', 'reimb', planId: 'p2'),
          buildPolicy('5', 'reimb', planId: 'p2'),
          buildPolicy('6', 'cancer1'),
          buildPolicy('7', 'rider', amount: 100),
          buildPolicy('8', 'unknown', amount: 100),
          buildPolicy('9', 'rider', amount: 300000, category: 'accident'),
        ],
        productCategories: categories,
        plansById: plans,
      );
      expect(result.currentOf('life'), 1500000);
      expect(result.currentOf('reimbursement_room'), 4000);
      expect(result.currentOf('reimbursement_hospital'), 400000);
      expect(result.currentOf('accident'), 300000); // 業務員改過類別
      expect(result.currentOf('cancer'), 0);
      expect(result.missingAmountCount, 1);
      expect(result.unknownCategoryCount, 1);
    });
  });

  testWidgets('健檢表格：有目標顯示還差多少或足夠，沒目標顯示未設定', (WidgetTester tester) async {
    const CoverageCheckResult result = CoverageCheckResult(
      currentByItem: {'life': 1000000, 'reimbursement_hospital': 400000},
      missingAmountCount: 0,
      unknownCategoryCount: 0,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 500, child: CoverageCheckTable(result: result, targets: {'life': 8000000, 'reimbursement_hospital': 300000})),
      ),
    ));
    expect(find.text('還差 7,000,000'), findsOneWidget);
    expect(find.text('✓ 足夠'), findsOneWidget);
    expect(find.text('未設定'), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });
}
