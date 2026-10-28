import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_sections.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
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
}) {
  final Map<String, dynamic> json = {
    'id': id,
    'customer_id': 'c1',
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
  group('保單狀態（4-I）', () {
    test('沒有 status 欄位時當作有效；lapsed 是已失效', () {
      expect(buildPolicy().isActive, isTrue);
      expect(buildPolicy().status, PolicyStatus.active);
      expect(buildPolicy(status: 'lapsed').isActive, isFalse);
      expect(PolicyStatus.label(PolicyStatus.active), '有效');
      expect(PolicyStatus.label(PolicyStatus.lapsed), '已失效');
    });

    test('切換狀態只改狀態，其他欄位不變', () {
      final CustomerEnrolledPolicy lapsed = buildPolicy().copyWithStatus(PolicyStatus.lapsed);
      expect(lapsed.isActive, isFalse);
      expect(lapsed.productName, '國泰人壽測試醫療終身保險');
      expect(lapsed.id, 'cp1');
    });

    test('理賠總額只算有效保單', () {
      const Map<String, dynamic> limits = {'room_daily': 2000, 'surgery_max': 100000, 'misc_max': 50000};
      final CustomerBenefitSummary summary = CustomerPolicyService().calculateCustomerBenefitSummary([
        buildPolicy(id: 'a', benefits: Map<String, dynamic>.from(limits)),
        buildPolicy(id: 'b', status: 'lapsed', benefits: Map<String, dynamic>.from(limits)),
      ]);
      expect(summary.countedPolicyCount, 1);
      expect(summary.totalRoomDaily, 2000);
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
        CustomerPoliciesSection(policies: [
          buildPolicy(id: 'm', productName: '國泰測試終身壽險', groupId: 'g1', role: 'main', policyNumber: 'A1', coverageAmount: 1000000),
          buildPolicy(id: 'r', productName: '國泰測試醫療附約', groupId: 'g1', role: 'rider', policyNumber: 'A1'),
          buildPolicy(id: 'c', productName: '南山人壽測試癌症保險', status: 'lapsed'),
        ], onScanPressed: () {}, onEditCoverage: (_) {}, onSetStatus: (_, __) {}, onDelete: (_) {}),
      );

      expect(find.text('保單（2 張）'), findsOneWidget);
      expect(find.text('有效保單'), findsOneWidget);
      expect(find.text('已失效保單'), findsOneWidget);
      expect(find.text('100 萬'), findsOneWidget);
      expect(find.text('國泰測試醫療附約'), findsNothing);
      await tester.tap(find.text('＋ 1 項附約'));
      await tester.pumpAndSettle();
      expect(find.text('國泰測試醫療附約'), findsOneWidget);
      expect(find.text('南山人壽測試癌症保險'), findsOneWidget);
      expect(find.text('手動加入'), findsOneWidget);
    });

    testWidgets('「⋯」整張標為已失效：把整張的每一項都交出去', (WidgetTester tester) async {
      List<CustomerEnrolledPolicy> changedItems = [];
      String changedStatus = '';
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(
          policies: [
            buildPolicy(id: 'm', groupId: 'g1', role: 'main'),
            buildPolicy(id: 'r', groupId: 'g1', role: 'rider'),
          ],
          onScanPressed: () {},
          onEditCoverage: (_) {},
          onSetStatus: (List<CustomerEnrolledPolicy> items, String status) {
            changedItems = items;
            changedStatus = status;
          },
          onDelete: (_) {},
        ),
      );
      await tester.tap(find.byTooltip('整張保單'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('整張標為已失效'));
      await tester.pumpAndSettle();
      expect(changedItems.length, 2);
      expect(changedStatus, PolicyStatus.lapsed);
    });

    testWidgets('沒有保單時顯示提示', (WidgetTester tester) async {
      bool scanPressed = false;
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(
          policies: const [],
          onScanPressed: () => scanPressed = true,
          onEditCoverage: (_) {},
          onSetStatus: (_, __) {},
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
