import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_sections.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/widgets/customer_policy_widgets.dart';

/// 依 customer_policies 欄位做一筆測試保單
CustomerEnrolledPolicy buildPolicy({
  String id = 'cp1',
  String productName = '國泰人壽測試醫療終身保險',
  String category = '醫療',
  String? status,
  Map<String, dynamic>? benefits,
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

    test('依險種分組，保留原本順序；沒有險種的歸到「其他」', () {
      final Map<String, List<CustomerEnrolledPolicy>> groups = CustomerPolicyService.groupPoliciesByCategory([
        buildPolicy(id: 'a', category: '醫療'),
        buildPolicy(id: 'b', category: '壽險'),
        buildPolicy(id: 'c', category: '醫療'),
        buildPolicy(id: 'd', category: ' '),
      ]);
      expect(groups.keys.toList(), ['醫療', '壽險', '其他']);
      expect(groups['醫療']!.length, 2);
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

  group('客戶完整頁的保單區（C-18）', () {
    testWidgets('分「有效保單」「已失效保單」兩區，各自依險種分組', (WidgetTester tester) async {
      await pumpWidgetInPage(
        tester,
        CustomerPoliciesSection(policies: [
          buildPolicy(id: 'a', productName: '國泰人壽測試醫療終身保險', category: '醫療'),
          buildPolicy(id: 'b', productName: '富邦人壽測試壽險', category: '壽險'),
          buildPolicy(id: 'c', productName: '南山人壽測試癌症保險', category: '癌症', status: 'lapsed'),
        ], onScanPressed: () {}),
      );

      expect(find.text('保單（3）'), findsOneWidget);
      expect(find.text('有效保單（2）'), findsOneWidget);
      expect(find.text('已失效保單（1）'), findsOneWidget);
      expect(find.text('醫療'), findsOneWidget);
      expect(find.text('壽險'), findsOneWidget);
      expect(find.text('癌症'), findsOneWidget);
      expect(find.text('南山人壽測試癌症保險'), findsOneWidget);
    });

    testWidgets('沒有保單時顯示提示', (WidgetTester tester) async {
      bool scanPressed = false;
      await pumpWidgetInPage(tester, CustomerPoliciesSection(policies: const [], onScanPressed: () => scanPressed = true));
      expect(find.text('保單（0）'), findsOneWidget);
      expect(find.textContaining('加到客戶'), findsOneWidget);
      // 右上角「掃描保單」（第 5 階段 E）
      await tester.tap(find.text('掃描保單'));
      expect(scanPressed, isTrue);
    });
  });

  group('側邊抽屜的保單列', () {
    testWidgets('有效保單顯示「標為已失效」，按了會呼叫切換', (WidgetTester tester) async {
      int toggleCount = 0;
      int openCount = 0;
      await pumpWidgetInPage(
        tester,
        EnrolledPolicyTile(
          policy: buildPolicy(),
          onToggleStatus: () => toggleCount++,
          onDelete: () {},
          onOpenProduct: () => openCount++,
        ),
      );
      expect(find.text('有效'), findsOneWidget);
      await tester.tap(find.text('標為已失效'));
      expect(toggleCount, 1);
      // 點商品名稱打開商品資料頁，不會誤觸切換
      await tester.tap(find.text('國泰人壽測試醫療終身保險'));
      expect(openCount, 1);
      expect(toggleCount, 1);
    });

    testWidgets('已失效保單顯示「改回有效」', (WidgetTester tester) async {
      await pumpWidgetInPage(
        tester,
        EnrolledPolicyTile(
          policy: buildPolicy(status: 'lapsed'),
          onToggleStatus: () {},
          onDelete: () {},
          onOpenProduct: () {},
        ),
      );
      expect(find.text('已失效'), findsOneWidget);
      expect(find.text('改回有效'), findsOneWidget);
    });
  });
}
