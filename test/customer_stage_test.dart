import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/screens/customers/customer_stage_filter_banner.dart';
import 'package:insurance_helper/services/customer_stage_service.dart';
import 'package:insurance_helper/services/insurance_product_service.dart';
import 'package:insurance_helper/widgets/customer_stage_summary_bar.dart';
import 'package:insurance_helper/widgets/product_compare_bar.dart';

Future<void> pumpInWidth(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))));
  await tester.pumpAndSettle();
}

InsuranceProduct buildProduct(String id, String code) {
  return InsuranceProduct.fromJson({
    'id': id,
    'company_code': 'cathay',
    'company_name': '國泰人壽',
    'product_code': code,
    'product_name': '國泰人壽測試保險 $code',
    'product_kind': 'main',
    'insurance_type': 'medical',
    'source_url': 'https://www.cathaylife.com.tw/list.pdf',
  });
}

void main() {
  group('客戶階段規則（選項 B）', () {
    test('有效保單優先算保戶；沒有保單但有拜訪算跟進中；都沒有算未開發', () {
      expect(CustomerStage.classify(hasActivePolicy: true, hasVisitActivity: true), CustomerStage.client);
      expect(CustomerStage.classify(hasActivePolicy: true, hasVisitActivity: false), CustomerStage.client);
      expect(CustomerStage.classify(hasActivePolicy: false, hasVisitActivity: true), CustomerStage.prospect);
      expect(CustomerStage.classify(hasActivePolicy: false, hasVisitActivity: false), CustomerStage.lead);
    });

    test('中文名稱與網址參數檢查', () {
      expect(CustomerStage.label(CustomerStage.client), '保戶');
      expect(CustomerStage.label(CustomerStage.prospect), '跟進中');
      expect(CustomerStage.label(CustomerStage.lead), '未開發');
      expect(CustomerStage.isValid('client'), isTrue);
      expect(CustomerStage.isValid('vip'), isFalse);
      expect(CustomerStage.isValid(null), isFalse);
    });

    test('數成三個數字', () {
      final CustomerStageSummary summary = CustomerStageService.summarize({
        'a': CustomerStage.client,
        'b': CustomerStage.prospect,
        'c': CustomerStage.prospect,
        'd': CustomerStage.lead,
      });
      expect(summary.totalCustomers, 4);
      expect(summary.countOf(CustomerStage.client), 1);
      expect(summary.countOf(CustomerStage.prospect), 2);
      expect(summary.countOf(CustomerStage.lead), 1);
    });

    test('客戶管理篩選：只留該階段；沒帶有效階段就全部顯示', () {
      final List<Map<String, dynamic>> customers = [
        {'id': 'a', 'name': '甲'},
        {'id': 'b', 'name': '乙'},
        {'id': 'c', 'name': '丙'},
      ];
      final Map<String, String> stages = {'a': CustomerStage.client, 'b': CustomerStage.lead};
      expect(CustomerStageService.filterByStage(customers, stages, 'client').map((c) => c['name']), ['甲']);
      expect(CustomerStageService.filterByStage(customers, stages, 'lead').map((c) => c['name']), ['乙']);
      expect(CustomerStageService.filterByStage(customers, stages, null).length, 3);
      expect(CustomerStageService.filterByStage(customers, stages, 'vip').length, 3);
    });

    test('跳到客戶管理的網址：/customers?stage=client', () {
      final Uri uri = Uri.parse(AppRoutes.customersStagePath(CustomerStage.client));
      expect(uri.path, AppRoutes.customers);
      expect(uri.queryParameters['stage'], 'client');
    });
  });

  group('畫面', () {
    testWidgets('客戶概況（電腦寬度）：標題、三張階段卡＋掃描卡，掃描卡可按（已是正式入口）', (WidgetTester tester) async {
      bool scanPressed = false;
      await pumpInWidth(
        tester,
        1200,
        CustomerStageSummaryBar(
          summary: const CustomerStageSummary(totalCustomers: 14, clientCount: 1, prospectCount: 12, leadCount: 1),
          onScanPressed: () => scanPressed = true,
        ),
      );
      expect(find.text('客戶概況'), findsOneWidget);
      expect(find.text('保戶'), findsOneWidget);
      expect(find.text('跟進中'), findsOneWidget);
      expect(find.text('未開發'), findsOneWidget);
      expect(find.text('有拜訪、未成交'), findsOneWidget);
      expect(find.text('掃描保單'), findsOneWidget);
      expect(find.text('開始掃描 ›'), findsOneWidget);
      expect(find.text('拍照辨識，加到客戶'), findsOneWidget);
      // 三張階段卡右上角都有箭頭，掃描卡沒有
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      await tester.tap(find.text('掃描保單'));
      expect(scanPressed, isTrue);
    });

    testWidgets('客戶概況（平板 600 寬）：改成 2 × 2，不擠', (WidgetTester tester) async {
      await pumpInWidth(
        tester,
        600,
        CustomerStageSummaryBar(
          summary: const CustomerStageSummary(totalCustomers: 14, clientCount: 1, prospectCount: 12, leadCount: 1),
          onScanPressed: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      final double clientTop = tester.getTopLeft(find.text('保戶')).dy;
      final double prospectTop = tester.getTopLeft(find.text('跟進中')).dy;
      final double leadTop = tester.getTopLeft(find.text('未開發')).dy;
      expect(prospectTop, clientTop); // 第一排：保戶、跟進中
      expect(leadTop, greaterThan(clientTop)); // 第二排：未開發、掃描
      expect(find.text('有效保單'), findsOneWidget);
    });

    testWidgets('客戶概況（手機 375）：2 × 2、說明藏起來、不擠', (WidgetTester tester) async {
      await pumpInWidth(
        tester,
        375,
        CustomerStageSummaryBar(
          summary: const CustomerStageSummary(totalCustomers: 14, clientCount: 1, prospectCount: 12, leadCount: 1),
          onScanPressed: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('跟進中'), findsOneWidget);
      expect(find.text('開始掃描 ›'), findsOneWidget);
      expect(find.text('有效保單'), findsNothing);
      expect(find.text('拍照辨識，加到客戶'), findsNothing);
    });

    testWidgets('客戶管理篩選列：顯示階段與人數，按 ✕ 取消', (WidgetTester tester) async {
      bool cleared = false;
      await pumpInWidth(
        tester,
        800,
        CustomerStageFilterBanner(stage: CustomerStage.client, count: 12, onClear: () => cleared = true),
      );
      expect(find.text('篩選：保戶（12 位）'), findsOneWidget);
      await tester.tap(find.byTooltip('取消篩選，看全部客戶'));
      expect(cleared, isTrue);
    });

    testWidgets('比較列在手機寬度精簡文字、不顯示代碼（D-09）', (WidgetTester tester) async {
      final List<InsuranceProduct> selected = [buildProduct('1', 'C64'), buildProduct('2', 'FPF')];
      await pumpInWidth(
        tester,
        375,
        ProductCompareBar(selectedProducts: selected, maximumCount: 8, onClear: () {}, onCompare: () {}),
      );
      expect(find.text('已選 2 款'), findsOneWidget);
      expect(find.text('比較'), findsOneWidget);
      expect(find.textContaining('C64'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('比較列在電腦寬度顯示完整文字與代碼', (WidgetTester tester) async {
      final List<InsuranceProduct> selected = [buildProduct('1', 'C64'), buildProduct('2', 'FPF')];
      await pumpInWidth(
        tester,
        1200,
        ProductCompareBar(selectedProducts: selected, maximumCount: 8, onClear: () {}, onCompare: () {}),
      );
      expect(find.text('已選 2/8 款商品'), findsOneWidget);
      expect(find.text('開始比較'), findsOneWidget);
      expect(find.text('C64  FPF'), findsOneWidget);
    });
  });
}
