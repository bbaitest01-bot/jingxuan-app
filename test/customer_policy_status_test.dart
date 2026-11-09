import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_sections.dart';
import 'package:insurance_helper/services/coverage_check_service.dart';
import 'package:insurance_helper/services/customer_card_summary_service.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/policy_detail_service.dart';
import 'package:insurance_helper/services/policy_party_service.dart';
import 'package:insurance_helper/services/policy_group_service.dart';
import 'package:insurance_helper/widgets/policy_group_card.dart';

/// 依 customer_policies 欄位做一筆測試保單
CustomerEnrolledPolicy buildPolicy({
  String id = 'cp1',
  String productName = '國泰人壽測試醫療終身保險',
  String category = '醫療',
  String? status,
  Map<String, dynamic>? benefits,
  String? groupId,
  String? role,
  String? policyNumber,
  int? coverageAmount,
  int? premium,
  String? premiumCurrency,
  String? paymentFrequency,
  int? reducedCoverageAmount,
  bool hasPolicyLoan = false,
  String? coverageCategory,
  String customerId = 'c1',
  String? policyholderId,
  String? insuredId,
  String? beneficiaryText,
}) {
  final Map<String, dynamic> json = {
    'id': id,
    'customer_id': customerId,
    'policy_clause_id': 'product-$id',
    'product_name': productName,
    'company_name': '國泰人壽',
    'category': category,
    'benefits_json': benefits ?? <String, dynamic>{},
    'enrolled_at': '2026-10-23T10:00:00Z',
  };
  if (status != null) {
    json['status'] = status;
  }
  json['policy_group_id'] = groupId;
  json['coverage_role'] = role;
  json['policy_number'] = policyNumber;
  json['coverage_amount'] = coverageAmount;
  json['premium'] = premium;
  json['premium_currency'] = premiumCurrency;
  json['payment_frequency'] = paymentFrequency;
  json['reduced_coverage_amount'] = reducedCoverageAmount;
  json['has_policy_loan'] = hasPolicyLoan;
  json['coverage_category'] = coverageCategory;
  json['policyholder_customer_id'] = policyholderId;
  json['insured_customer_id'] = insuredId;
  json['beneficiary_text'] = beneficiaryText;
  return CustomerEnrolledPolicy.fromJson(json);
}

Future<void> pumpWidgetInPage(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pumpAndSettle();
}

void main() {
  group('保單張數：主約和附約算同一張（D35）', () {
    final List<CustomerEnrolledPolicy> policies = [
      buildPolicy(id: 'main', groupId: 'g1', role: 'main', status: 'active'),
      buildPolicy(id: 'rider1', groupId: 'g1', role: 'rider', status: 'active'),
      buildPolicy(id: 'rider2', groupId: 'g1', role: 'rider', status: 'active'),
      buildPolicy(id: 'cancer', status: 'lapsed'),
    ];

    test('一張主約＋2 附約、一張失效：有效 1 張、全部 2 張', () {
      expect(PolicyGrouping.countActivePolicies(policies), 1);
      expect(PolicyGrouping.group(policies).length, 2);
    });

    test('主約失效但附約還有效：這張還算有效', () {
      final List<CustomerEnrolledPolicy> partlyLapsed = [
        buildPolicy(id: 'main', groupId: 'g1', role: 'main', status: 'lapsed'),
        buildPolicy(id: 'rider1', groupId: 'g1', role: 'rider', status: 'active'),
      ];
      expect(PolicyGrouping.countActivePolicies(partlyLapsed), 1);
    });

    test('客戶卡片：同一張算一次，沒有編號的單獨算一張', () {
      final Map<String, int> counts = CustomerCardSummaryService.countPoliciesByCustomer([
        {'id': '1', 'customer_id': 'a', 'company_name': '國泰人壽', 'policy_group_id': 'g1', 'policy_number': null},
        {'id': '2', 'customer_id': 'a', 'company_name': '國泰人壽', 'policy_group_id': 'g1', 'policy_number': null},
        {'id': '3', 'customer_id': 'a', 'company_name': '南山人壽', 'policy_group_id': null, 'policy_number': null},
        {'id': '4', 'customer_id': 'b', 'company_name': '南山人壽', 'policy_group_id': null, 'policy_number': null},
      ]);
      expect(counts, {'a': 2, 'b': 1});
    });
  });

  group('保單狀態細分（2026-11-07 主管回饋）', () {
    test('沒有 status 欄位時當作有效；六種狀態的中文', () {
      expect(buildPolicy().isActive, isTrue);
      expect(buildPolicy().status, PolicyStatus.active);
      expect(PolicyStatus.label(PolicyStatus.lapsed), '停效');
      expect(PolicyStatus.label(PolicyStatus.reducedPaidUp), '減額繳清');
      expect(PolicyStatus.label(PolicyStatus.surrendered), '解約');
    });

    test('有效、減額繳清、展期定期有保障；停效、解約、滿期沒有', () {
      for (final String status in PolicyStatus.withCoverage) {
        expect(buildPolicy(status: status).isActive, isTrue, reason: status);
      }
      for (final String status in PolicyStatus.withoutCoverage) {
        expect(buildPolicy(status: status).isActive, isFalse, reason: status);
      }
    });

    test('保單貸款是加註：有貸款的保單仍然有效', () {
      final CustomerEnrolledPolicy policy = buildPolicy(hasPolicyLoan: true);
      expect(policy.hasPolicyLoan, isTrue);
      expect(policy.isActive, isTrue);
    });

    test('健檢：減額繳清用新保額，停效不算', () {
      final CoverageCheckResult result = CoverageCheckService.calculate(
        policies: [
          buildPolicy(id: 'a', coverageCategory: 'life', coverageAmount: 1000000),
          buildPolicy(id: 'b', coverageCategory: 'life', coverageAmount: 500000, status: PolicyStatus.reducedPaidUp, reducedCoverageAmount: 200000),
          buildPolicy(id: 'c', coverageCategory: 'life', coverageAmount: 300000, status: PolicyStatus.lapsed),
        ],
        productCategories: const {},
        plansById: const {},
      );
      expect(result.currentOf('life'), 1200000);
    });
  });

  group('保單的三個人（2026-11-07 主管回饋）', () {
    test('沒填時要保人、被保險人都是保單掛的客戶自己', () {
      final CustomerEnrolledPolicy policy = buildPolicy();
      expect(policy.effectiveInsuredId, 'c1');
      expect(policy.effectivePolicyholderId, 'c1');
      expect(policy.hasPartyDetails, isFalse);
    });

    test('健檢：媽媽幫兒子買的保單算在兒子，不算在媽媽', () {
      final CustomerEnrolledPolicy forSon = buildPolicy(id: 'son', customerId: 'mom', insuredId: 'kid');
      final CustomerEnrolledPolicy forMom = buildPolicy(id: 'mom-own', customerId: 'mom');
      expect(PolicyPartyService.policiesCoveringCustomer('mom', [forSon, forMom], const []).map((p) => p.id), ['mom-own']);
      expect(PolicyPartyService.policiesCoveringCustomer('kid', const [], [forSon]).map((p) => p.id), ['son']);
    });

    test('有填受益人文字就算填過三個人', () {
      expect(buildPolicy(beneficiaryText: '法定繼承人').hasPartyDetails, isTrue);
      expect(buildPolicy(policyholderId: 'wife').effectivePolicyholderId, 'wife');
    });
  });

  group('保費與繳別（2026-11-07 主管回饋）', () {
    test('一年保費＝每期保費 × 一年繳幾次', () {
      expect(PolicyDetailService.annualPremiumOf(buildPolicy(premium: 1500, paymentFrequency: PaymentFrequency.monthly)), 18000);
      expect(PolicyDetailService.annualPremiumOf(buildPolicy(premium: 10000, paymentFrequency: PaymentFrequency.semiannual)), 20000);
      expect(PolicyDetailService.annualPremiumOf(buildPolicy(premium: 5000, paymentFrequency: PaymentFrequency.annual)), 5000);
    });

    test('躉繳、沒填繳別、不用再繳（減額繳清、停效）都不算一年保費', () {
      expect(PolicyDetailService.annualPremiumOf(buildPolicy(premium: 300000, paymentFrequency: PaymentFrequency.single)), isNull);
      expect(PolicyDetailService.annualPremiumOf(buildPolicy(premium: 1500)), isNull);
      expect(PolicyDetailService.annualPremiumOf(
          buildPolicy(premium: 1500, paymentFrequency: PaymentFrequency.monthly, status: PolicyStatus.reducedPaidUp)), isNull);
      expect(PolicyDetailService.annualPremiumOf(
          buildPolicy(premium: 1500, paymentFrequency: PaymentFrequency.monthly, status: PolicyStatus.lapsed)), isNull);
    });

    test('一年總保費：台幣、美元分開加；沒填繳別的張數另外數', () {
      final AnnualPremiumSummary summary = PolicyDetailService.summarize([
        buildPolicy(id: 'a', groupId: 'g1', premium: 1500, paymentFrequency: PaymentFrequency.monthly),
        buildPolicy(id: 'b', groupId: 'g1', premium: 550, paymentFrequency: PaymentFrequency.monthly),
        buildPolicy(id: 'c', premium: 4215, premiumCurrency: 'USD', paymentFrequency: PaymentFrequency.annual),
        buildPolicy(id: 'd', groupId: 'g2', premium: 3000),
      ]);
      expect(summary.totalByCurrency['TWD'], 24600);
      expect(summary.totalByCurrency['USD'], 4215);
      expect(summary.missingFrequencyGroupCount, 1);
      expect(PolicyDetailService.formatAnnualTotal(summary), '24,600 元＋USD 4,215');
    });
  });

  group('一張保單一張卡片（D21）', () {
    test('同保單編號歸成一張，主約排第一；手動加入的自己一張', () {
      final List<PolicyGroup> groups = PolicyGrouping.group([
        buildPolicy(id: 'r1', groupId: 'g1', role: 'rider', policyNumber: 'A123'),
        buildPolicy(id: 'm1', groupId: 'g1', role: 'main', policyNumber: 'A123'),
        buildPolicy(id: 'x'),
        buildPolicy(id: 'r2', groupId: 'g1', role: 'rider'),
      ]);
      expect(groups.length, 2);
      expect(groups[0].items.map((CustomerEnrolledPolicy item) => item.id).toList(), ['m1', 'r1', 'r2']);
      expect(groups[0].policyNumber, 'A123');
      expect(groups[0].isManual, isFalse);
      expect(groups[1].isManual, isTrue);
    });

    test('沒有保單編號但同公司同保單號碼也算同一張', () {
      final List<PolicyGroup> groups = PolicyGrouping.group([
        buildPolicy(id: 'a', policyNumber: 'B9'),
        buildPolicy(id: 'b', policyNumber: ' B9 '),
      ]);
      expect(groups.length, 1);
    });

    test('整張都失效才算已失效', () {
      final List<PolicyGroup> partly = PolicyGrouping.group([
        buildPolicy(id: 'a', groupId: 'g', role: 'main'),
        buildPolicy(id: 'b', groupId: 'g', status: 'lapsed'),
      ]);
      expect(partly.single.isAllLapsed, isFalse);
      final List<PolicyGroup> all = PolicyGrouping.group([
        buildPolicy(id: 'a', groupId: 'g', status: 'lapsed'),
        buildPolicy(id: 'b', groupId: 'g', status: 'lapsed'),
      ]);
      expect(all.single.isAllLapsed, isTrue);
    });

    test('金額文字：萬為單位，沒有保額用計畫', () {
      expect(policyAmountText(buildPolicy(coverageAmount: 1000000)), '100 萬');
      expect(policyAmountText(buildPolicy(coverageAmount: 15000)), '1.5 萬');
      expect(policyAmountText(buildPolicy(coverageAmount: 3500)), '3,500');
      expect(policyAmountText(buildPolicy()), '');
    });
  });

  group('點保單跳到數據戰情', () {
    test('網址帶商品編號：/insights?product=…', () {
      expect(AppRoutes.insightsProductPath('abc-123'), '/insights?product=abc-123');
      final Uri uri = Uri.parse(AppRoutes.insightsProductPath('abc-123'));
      expect(uri.path, AppRoutes.insights);
      expect(uri.queryParameters['product'], 'abc-123');
      expect(AppRoutes.menuForPath(uri.path), '數據戰情');
    });
  });

  group('客戶完整頁的保單區（D21）', () {
    testWidgets('一張保單一張卡片：收合只顯示主約，點開看附約；整張失效放已失效', (WidgetTester tester) async {
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(customerId: 'c1', policies: [
          buildPolicy(id: 'm', productName: '國泰測試終身壽險', groupId: 'g1', role: 'main', policyNumber: 'A1', coverageAmount: 1000000),
          buildPolicy(id: 'r', productName: '國泰測試醫療附約', groupId: 'g1', role: 'rider', policyNumber: 'A1'),
          buildPolicy(id: 'c', productName: '南山人壽測試癌症保險', status: 'lapsed'),
        ], onScanPressed: () {}, onEditCoverage: (_) {}, onPolicyChanged: () {}, onDelete: (_) {}),
      );

      expect(find.text('保單（2 張）'), findsOneWidget);
      // 上方摘要一格、下方分區標題一個
      expect(find.text('有效保單'), findsNWidgets(2));
      expect(find.text('已失效保單'), findsOneWidget);
      expect(find.text('100 萬'), findsOneWidget);
      expect(find.text('國泰測試醫療附約'), findsNothing);
      await tester.tap(find.text('＋ 1 項附約'));
      await tester.pumpAndSettle();
      expect(find.text('國泰測試醫療附約'), findsOneWidget);
      expect(find.text('南山人壽測試癌症保險'), findsOneWidget);
      expect(find.text('手動加入'), findsOneWidget);
    });

    testWidgets('卡片顯示狀態標籤、每期保費、一年總保費；沒填繳別會提醒', (WidgetTester tester) async {
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(
          customerId: 'c1',
          policies: [
            buildPolicy(id: 'm', groupId: 'g1', role: 'main', premium: 1500, paymentFrequency: PaymentFrequency.monthly, hasPolicyLoan: true),
            buildPolicy(id: 'n', groupId: 'g2', role: 'main', premium: 3000, status: PolicyStatus.reducedPaidUp, coverageAmount: 500000, reducedCoverageAmount: 200000),
            buildPolicy(id: 'x', productName: '南山人壽測試癌症保險', status: PolicyStatus.lapsed),
          ],
          onScanPressed: () {},
          onEditCoverage: (_) {},
          onPolicyChanged: () {},
          onDelete: (_) {},
        ),
      );
      expect(find.text('一年總保費'), findsOneWidget);
      expect(find.text('18,000 元'), findsOneWidget);
      expect(find.text('有貸款'), findsOneWidget);
      expect(find.text('減額繳清'), findsOneWidget);
      expect(find.text('停效・可復效'), findsOneWidget);
      expect(find.text('每期 1,500 元'), findsOneWidget);
      expect(find.textContaining('降為 20 萬'), findsOneWidget);
      expect(find.text('還沒填生效日'), findsOneWidget);
      // 停效的保單不提醒
      expect(find.text('還沒填繳別、生效日'), findsOneWidget);
    });

    testWidgets('「⋯」有「更改狀態」，點開是六種狀態', (WidgetTester tester) async {
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(
          customerId: 'c1',
          policies: [buildPolicy(id: 'm', groupId: 'g1', role: 'main')],
          onScanPressed: () {},
          onEditCoverage: (_) {},
          onPolicyChanged: () {},
          onDelete: (_) {},
        ),
      );
      await tester.tap(find.byTooltip('整張保單'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更改狀態'));
      await tester.pumpAndSettle();
      expect(find.text('保單狀態'), findsOneWidget);
      for (final String label in PolicyStatus.labels.values) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(ChoiceChip, '減額繳清'));
      await tester.pumpAndSettle();
      expect(find.text('減額繳清後的新保額'), findsOneWidget);
    });

    testWidgets('沒有保單時顯示提示', (WidgetTester tester) async {
      bool scanPressed = false;
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(
          customerId: 'c1',
          policies: const [],
          onScanPressed: () => scanPressed = true,
          onEditCoverage: (_) {},
          onPolicyChanged: () {},
          onDelete: (_) {},
        ),
      );
      expect(find.text('保單（0 張）'), findsOneWidget);
      expect(find.textContaining('加到客戶'), findsOneWidget);
      // 右上角「掃描保單」（第 5 階段 E）
      await tester.tap(find.text('掃描保單'));
      expect(scanPressed, isTrue);
    });
  });
}
