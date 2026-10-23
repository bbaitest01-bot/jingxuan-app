import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/insurance_product_service.dart';
import 'package:insurance_helper/services/policy_scan_service.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_capture_panel.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_customer_picker_dialog.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_notice_dialog.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_review_panel.dart';

InsuranceProduct buildCatalogProduct(String id, String name, {String kind = 'main', String type = 'life'}) {
  return InsuranceProduct.fromJson({
    'id': id,
    'company_code': 'cathay',
    'company_name': '國泰人壽',
    'product_name': name,
    'product_kind': kind,
    'insurance_type': type,
    'clause_url': 'https://www.cathaylife.com.tw/$id.pdf',
    'source_url': 'https://www.cathaylife.com.tw/list.pdf',
  });
}

Future<void> pumpInWidth(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pumpAndSettle();
}

void main() {
  group('解析雲端函式回傳（只有商品欄位）', () {
    test('讀出公司、保單號碼、生效日與每個商品', () {
      final ScannedPolicy policy = PolicyScanService.parseScanResponse({
        'company_name': '國泰人壽保險股份有限公司',
        'policy_number': 'TEST-CA-0001',
        'effective_date': '2025-03-01',
        'items': [
          {'product_name': '國泰人壽新GO心保障100定期壽險', 'coverage_role': 'main', 'plan_or_amount': '100 萬元', 'premium': 8520},
          {'product_name': '國泰人壽新金骨力傷害暨兒童意外骨折保險附約', 'coverage_role': 'rider', 'plan_or_amount': '計畫 2', 'premium': null},
          {'product_name': '   '},
        ],
      });
      expect(policy.companyCode, 'cathay');
      expect(policy.policyNumber, 'TEST-CA-0001');
      expect(policy.effectiveDate, DateTime(2025, 3, 1));
      expect(policy.items.length, 2); // 空白名稱的那筆丟掉
      expect(policy.items.first.coverageRole, 'main');
      expect(policy.items.first.premium, 8520);
      expect(policy.items[1].premium, isNull);
    });

    test('保單上沒讀到公司名稱時，從商品名稱推回公司', () {
      final ScannedPolicy policy = PolicyScanService.parseScanResponse({
        'items': [
          {'product_name': '南山人壽心滿溢足癌症健康保險'},
        ],
      });
      expect(policy.companyCode, 'nanshan');
    });

    test('目錄沒有的公司回傳 null', () {
      expect(PolicyScanService.companyCodeFromText('富邦人壽保險股份有限公司'), 'fubon');
      expect(PolicyScanService.companyCodeFromText('新光人壽'), isNull);
    });
  });

  group('對商品目錄', () {
    final List<InsuranceProduct> catalog = [
      buildCatalogProduct('p1', '國泰人壽終身防癌健康保險附約'),
      buildCatalogProduct('p2', '國泰人壽新終身防癌健康保險附約'),
      buildCatalogProduct('p3', '國泰人壽真漾心安住院醫療終身保險（甲型）'),
    ];

    test('名稱相同（忽略公司名稱、空白、全半形括號）才算對到', () {
      expect(PolicyScanService.findCatalogMatch('國泰人壽新終身防癌健康保險附約', catalog)?.id, 'p2');
      expect(PolicyScanService.findCatalogMatch('新終身防癌健康保險附約', catalog)?.id, 'p2');
      expect(PolicyScanService.findCatalogMatch('國泰人壽 真漾心安住院醫療終身保險(甲型)', catalog)?.id, 'p3');
    });

    test('只是名稱「包含」不算對到，避免對錯成舊商品', () {
      expect(PolicyScanService.findCatalogMatch('國泰人壽防癌健康保險附約', catalog), isNull);
      expect(PolicyScanService.findCatalogMatch('', catalog), isNull);
    });
  });

  group('存入資料庫的內容（存法 A：一個商品一筆）', () {
    ScannedPolicy buildPolicy() {
      return ScannedPolicy(
        companyCode: 'cathay',
        companyName: '國泰人壽保險股份有限公司',
        policyNumber: 'TEST-CA-0001',
        effectiveDate: DateTime(2025, 3, 1),
        items: [
          ScannedPolicyItem(
            productName: '國泰人壽新GO心保障100定期壽險',
            coverageRole: 'main',
            planOrAmount: '100 萬元',
            premium: 8520,
            matchedProduct: buildCatalogProduct('p9', '國泰人壽新GO心保障100定期壽險'),
          ),
          ScannedPolicyItem(productName: '國泰人壽住院醫療費用保險附約（舊型）', coverageRole: 'rider', planOrAmount: '計畫 3'),
        ],
      );
    }

    test('同一份保單共用 policy_group_id，來源標成 scan，限額明確寫空值', () {
      final List<Map<String, dynamic>> rows = PolicyScanService.buildPolicyRows(
        customerId: 'c1',
        policy: buildPolicy(),
        status: PolicyStatus.active,
        policyGroupId: 'group-1',
      );
      expect(rows.length, 2);
      for (final Map<String, dynamic> row in rows) {
        expect(row['policy_group_id'], 'group-1');
        expect(row['source'], 'scan');
        expect(row['policy_number'], 'TEST-CA-0001');
        expect(row['effective_date'], '2025-03-01');
        expect(row.containsKey('room_limit'), isTrue);
        expect(row['room_limit'], isNull);
      }
      // 不會出現任何個資欄位
      expect(rows.first.keys.where((String key) => key.contains('id_number') || key.contains('insured')), isEmpty);
    });

    test('對到目錄的用目錄資料；找不到的照樣存、商品編號空白、險種「未分類」', () {
      final List<Map<String, dynamic>> rows = PolicyScanService.buildPolicyRows(
        customerId: 'c1',
        policy: buildPolicy(),
        status: PolicyStatus.lapsed,
        policyGroupId: 'group-1',
      );
      expect(rows.first['policy_clause_id'], 'p9');
      expect(rows.first['category'], '壽險');
      expect(rows.first['premium'], 8520);
      expect(rows[1]['policy_clause_id'], isNull);
      expect(rows[1]['company_name'], '國泰人壽');
      expect(rows[1]['category'], '未分類');
      expect(rows[1]['status'], PolicyStatus.lapsed);
    });

    test('同一份保單的編號（UUID）格式正確且每次不同', () {
      final String first = PolicyScanService.generateUuid();
      final String second = PolicyScanService.generateUuid();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(first), isTrue);
      expect(first, isNot(second));
    });

    test('讀回資料庫時帶出掃描欄位', () {
      final CustomerEnrolledPolicy policy = CustomerEnrolledPolicy.fromJson({
        'id': 'x',
        'customer_id': 'c1',
        'policy_clause_id': null,
        'product_name': '某舊商品',
        'company_name': '國泰人壽',
        'coverage_role': 'rider',
        'plan_or_amount': '計畫三',
        'effective_date': '2025-03-01',
        'premium': 3880,
        'source': 'scan',
      });
      expect(policy.isInCatalog, isFalse);
      expect(policy.coverageRoleLabel, '附約');
      expect(policy.copyWithStatus(PolicyStatus.lapsed).planOrAmount, '計畫三');
      expect(policy.source, 'scan');
    });
  });

  group('畫面', () {
    test('電話只露出前四碼與後三碼', () {
      expect(maskPhoneNumber('0912345678'), '0912-***-678');
      expect(maskPhoneNumber('123'), '123');
    });

    testWidgets('手機：有「拍照」和「上傳檔案」', (WidgetTester tester) async {
      await pumpInWidth(
        tester,
        375,
        ScanCapturePanel(
          isMobileDevice: true,
          images: const [],
          maximumImageCount: 3,
          onTakePhoto: () {},
          onUploadFile: () {},
          onRemoveImage: (_) {},
          onStartRecognize: () {},
        ),
      );
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('上傳檔案'), findsOneWidget);
      expect(find.text('紙本保單請用手機或平板開啟本頁拍照'), findsNothing);
      expect(find.text('開始辨識'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('電腦：只有「上傳檔案」，並提醒紙本改用手機', (WidgetTester tester) async {
      await pumpInWidth(
        tester,
        1200,
        ScanCapturePanel(
          isMobileDevice: false,
          // 1 × 1 的白色 PNG，當作已選的一張
          images: [base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=')],
          maximumImageCount: 3,
          onTakePhoto: () {},
          onUploadFile: () {},
          onRemoveImage: (_) {},
          onStartRecognize: () {},
        ),
      );
      expect(find.text('拍照'), findsNothing);
      expect(find.text('紙本保單請用手機或平板開啟本頁拍照'), findsOneWidget);
      expect(find.text('已選 1/3 張'), findsOneWidget);
      expect(find.text('開始辨識'), findsOneWidget);
    });

    testWidgets('確認畫面：標示對到目錄與找不到，按鈕顯示項數', (WidgetTester tester) async {
      bool saved = false;
      await pumpInWidth(
        tester,
        375,
        ScanReviewPanel(
          customerName: '王測一',
          policy: ScannedPolicy(
            companyCode: 'cathay',
            effectiveDate: DateTime(2025, 3, 1),
            items: [
              ScannedPolicyItem(
                productName: '國泰人壽新GO心保障100定期壽險',
                coverageRole: 'main',
                matchedProduct: buildCatalogProduct('p9', '國泰人壽新GO心保障100定期壽險'),
              ),
              ScannedPolicyItem(productName: '某舊商品附約', coverageRole: 'rider', planOrAmount: '計畫 3'),
            ],
          ),
          status: PolicyStatus.active,
          isSaving: false,
          onEditItem: (_) {},
          onRemoveItem: (_) {},
          onAddItem: () {},
          onStatusChanged: (_) {},
          onRescan: () {},
          onSave: () => saved = true,
        ),
      );
      expect(find.text('王測一・國泰人壽・生效日 2025/03/01'), findsOneWidget);
      expect(find.text('主約'), findsOneWidget);
      expect(find.text('附約'), findsOneWidget);
      expect(find.textContaining('已對到商品目錄 ✓'), findsOneWidget);
      expect(find.textContaining('目錄中找不到此商品，仍會存入'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('存入客戶保單（2 項）'));
      expect(saved, isTrue);
    });

    Future<bool?> openNoticeDialog(WidgetTester tester, {required bool showPrivacyDetails}) async {
      bool? agreed;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => agreed = await showScanNoticeDialog(
              context,
              customerName: '王測一',
              showPrivacyDetails: showPrivacyDetails,
            ),
            child: const Text('打開'),
          ),
        ),
      ));
      await tester.tap(find.text('打開'));
      await tester.pumpAndSettle();

      // 沒勾「已向 王測一 說明並取得同意」之前，「開始掃描」按不下去
      final Finder startButton = find.widgetWithText(ElevatedButton, '開始掃描');
      expect(tester.widget<ElevatedButton>(startButton).onPressed, isNull);
      expect(find.textContaining('可以這樣跟客戶說'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      return agreed;
    }

    testWidgets('第一次掃描：完整說明＋勾選同意才能開始', (WidgetTester tester) async {
      final bool? agreed = await openNoticeDialog(tester, showPrivacyDetails: true);
      expect(agreed, isTrue);
    });

    testWidgets('之後每次掃描：一樣要勾選這位客戶的同意，但不再顯示完整說明', (WidgetTester tester) async {
      bool? agreed;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => agreed = await showScanNoticeDialog(
              context,
              customerName: '王測一',
              showPrivacyDetails: false,
            ),
            child: const Text('打開'),
          ),
        ),
      ));
      await tester.tap(find.text('打開'));
      await tester.pumpAndSettle();
      expect(find.text('掃描前請先取得同意'), findsOneWidget);
      expect(find.textContaining('辨識完立即刪除'), findsNothing);
      expect(find.textContaining('王測一', findRichText: true), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(agreed, isFalse);

      expect(await openNoticeDialog(tester, showPrivacyDetails: false), isTrue);
    });
  });
}
