import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/insurance_product_service.dart';
import 'package:insurance_helper/services/policy_scan_merge.dart';
import 'package:insurance_helper/services/policy_scan_service.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_capture_panel.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_customer_picker_dialog.dart';
import 'package:insurance_helper/widgets/scan_policy/scan_duplicate_dialog.dart';
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
      expect(rows.first['coverage_amount'], 1000000); // 「100 萬元」轉成保額
      expect(rows[1]['benefit_plan_id'], isNull); // 目錄找不到，沒有計畫可對
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
          onApplySuggestion: (_) {},
          onAddItem: () {},
          onRetake: () {},
          onUseRetakeValue: (_) {},
          onStatusChanged: (_) {},
          onRescan: () {},
          onSave: () => saved = true,
        ),
      );
      expect(find.text('國泰人壽'), findsOneWidget);
      expect(find.textContaining('2025/03/01', findRichText: true), findsOneWidget);
      expect(find.text('主約'), findsOneWidget);
      expect(find.text('附約'), findsOneWidget);
      // 只有目錄找不到的才標示；上方結果寫有 1 件事要確認
      expect(find.textContaining('目錄找不到，仍會存入'), findsOneWidget);
      expect(find.text('有 1 件事要確認'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 沒勾項數確認不能存
      await tester.tap(find.text('存入客戶保單（2 項）'));
      await tester.pump();
      expect(saved, isFalse);
      await tester.tap(find.textContaining('保單上共 2 項'));
      await tester.pump();
      await tester.tap(find.text('存入客戶保單（2 項）'));
      expect(saved, isTrue);
      await tester.pump(const Duration(seconds: 5));
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

  group('手機實測後的修正（2026-10-24：漏項、讀錯字、美元、重複保單）', () {
    final List<InsuranceProduct> catalog = [
      buildCatalogProduct('s1', '國泰人壽睛彩人生PLUS手術醫療健康保險附約（外溢型）', kind: 'rider'),
      buildCatalogProduct('s2', '國泰人壽心安PLUS加護燒燙傷病房醫療終身健康保險附約（外溢型）', kind: 'rider'),
      buildCatalogProduct('s3', '國泰人壽終身防癌健康保險附約', kind: 'rider'),
      buildCatalogProduct('s4', '國泰人壽新終身防癌健康保險附約', kind: 'rider'),
    ];

    test('讀錯一兩個字：找出「可能是」的商品', () {
      expect(PolicyScanService.findSimilarProduct('國泰人壽精彩人生PLUS手術醫療健康保險附約（外溢型）', catalog)?.id, 's1');
      expect(PolicyScanService.findSimilarProduct('國泰人壽心安PLUS加護護燙傷病房醫療終身健康保險附約（外溢型）', catalog)?.id, 's2');
      // 長名稱差 3 個字也要找得到（2026-10-25 國泰 PDF 實測）
      expect(PolicyScanService.findSimilarProduct('國泰人壽心安PLUS加護病房燒傷病房醫療終身健康保險附約（外溢型）', catalog)?.id, 's2');
    });

    test('差太多、或有兩款一樣接近時不建議', () {
      expect(PolicyScanService.findSimilarProduct('國泰人壽完全不一樣的商品名稱', catalog), isNull);
      // 「舊終身防癌」跟「終身防癌」「新終身防癌」各差 1、1 個字 → 一樣接近，不建議
      expect(PolicyScanService.findSimilarProduct('國泰人壽舊終身防癌健康保險附約', catalog), isNull);
    });

    test('編輯距離', () {
      expect(PolicyScanService.editDistance('睛彩人生', '精彩人生'), 1);
      expect(PolicyScanService.editDistance('abc', 'abc'), 0);
      expect(PolicyScanService.editDistance('', 'ab'), 2);
    });

    test('按「套用」換成目錄商品', () {
      final ScannedPolicyItem item = ScannedPolicyItem(productName: '國泰人壽精彩人生', suggestedProduct: catalog.first);
      item.applySuggestion();
      expect(item.isInCatalog, isTrue);
      expect(item.productName, catalog.first.productName);
      expect(item.suggestedProduct, isNull);
    });

    test('總項數比讀到的多：算出漏了幾項；幣別一起存', () {
      final ScannedPolicy policy = PolicyScanService.parseScanResponse({
        'company_name': '南山人壽保險股份有限公司',
        'item_count': 11,
        'items': [
          {'product_name': '南山人壽御守護美元利率變動型終身壽險（定期給付型）', 'coverage_role': 'main', 'premium': 4215, 'premium_currency': 'USD'},
        ],
      });
      expect(policy.expectedItemCount, 11);
      expect(policy.missingItemCount, 10);
      expect(policy.items.first.premiumCurrency, 'USD');
      final List<Map<String, dynamic>> rows = PolicyScanService.buildPolicyRows(
        customerId: 'c1',
        policy: policy,
        status: PolicyStatus.active,
        policyGroupId: 'g',
      );
      expect(rows.first['premium_currency'], 'USD');
      // 外幣保額不轉（保單健檢以新臺幣計）
      expect(rows.first['coverage_amount'], isNull);
    });

    test('保費文字：新臺幣加「元」與千分位、外幣顯示幣別', () {
      expect(formatPremiumText(12350, null), '保費 12,350 元');
      expect(formatPremiumText(188, 'TWD'), '保費 188 元');
      expect(formatPremiumText(4215, 'USD'), '保費 USD 4,215');
    });

    testWidgets('確認畫面：漏項黃色提醒、「可能是」可以套用', (WidgetTester tester) async {
      int appliedIndex = -1;
      await pumpInWidth(
        tester,
        375,
        ScanReviewPanel(
          customerName: '王測一',
          policy: ScannedPolicy(
            companyCode: 'cathay',
            expectedItemCount: 9,
            items: [
              ScannedPolicyItem(productName: '國泰人壽精彩人生PLUS手術醫療', coverageRole: 'rider', suggestedProduct: catalog.first),
            ],
          ),
          status: PolicyStatus.active,
          isSaving: false,
          onEditItem: (_) {},
          onRemoveItem: (_) {},
          onApplySuggestion: (int index) => appliedIndex = index,
          onAddItem: () {},
          onRetake: () {},
          onUseRetakeValue: (_) {},
          onStatusChanged: (_) {},
          onRescan: () {},
          onSave: () {},
        ),
      );
      expect(find.textContaining('保單上可能有 9 項，只讀到 1 項'), findsOneWidget);
      expect(find.textContaining('可能是：國泰人壽睛彩人生'), findsOneWidget);
      await tester.tap(find.text('套用'));
      expect(appliedIndex, 0);
      // 有沒套用的建議時，存入前會列出來，可以「全部套用並存入」
      appliedIndex = -1;
      await tester.tap(find.textContaining('保單上共 1 項'));
      await tester.pump();
      await tester.tap(find.text('存入客戶保單（1 項）'));
      await tester.pumpAndSettle();
      expect(find.text('還有 1 項沒處理'), findsOneWidget);
      await tester.tap(find.text('全部套用並存入'));
      await tester.pumpAndSettle();
      expect(appliedIndex, 0);
      expect(tester.takeException(), isNull);
    });

    test('兩張照片分開辨識後合併：保單資料取有寫的、同名商品留資料多的、總項數取最大', () {
      final ScannedPolicy cover = ScannedPolicy(
        companyCode: 'fubon',
        policyNumber: 'A123',
        expectedItemCount: 8,
        items: [ScannedPolicyItem(productName: '富邦人壽美好人生終身壽險', coverageRole: 'main')],
      );
      final ScannedPolicy table = ScannedPolicy(
        effectiveDate: DateTime(2024, 3, 1),
        expectedItemCount: 8,
        items: [
          ScannedPolicyItem(productName: '富邦人壽美好人生終身壽險', coverageRole: 'main', planOrAmount: '100萬', premium: 30000),
          ScannedPolicyItem(productName: '富邦人壽實支實付醫療附約', coverageRole: 'rider', planOrAmount: '計畫三', premium: 3500),
        ],
      );
      final ScannedPolicy merged = PolicyScanMerge.mergePages([cover, table]);
      expect(merged.policyNumber, 'A123');
      expect(merged.effectiveDate, DateTime(2024, 3, 1));
      expect(merged.expectedItemCount, 8);
      expect(merged.items.length, 2);
      expect(merged.items.first.premium, 30000);
      expect(merged.sentWholePhoto, isFalse);
    });

    test('補拍比對：新項目加入、重複略過、金額不同標出、保單號碼不同提醒', () {
      final ScannedPolicy first = ScannedPolicy(companyCode: 'fubon', policyNumber: 'A123', items: [
        ScannedPolicyItem(productName: '富邦人壽美好人生終身壽險', coverageRole: 'main', premium: 30000),
        ScannedPolicyItem(productName: '富邦人壽實支實付醫療附約', coverageRole: 'rider', planOrAmount: '計畫三', premium: 3500),
      ]);
      final ScannedPolicy retake = ScannedPolicy(companyCode: 'fubon', policyNumber: 'A123', effectiveDate: DateTime(2024, 3, 1), items: [
        ScannedPolicyItem(productName: '富邦人壽實支實付醫療附約', coverageRole: 'rider', planOrAmount: '計畫二', premium: 3500),
        ScannedPolicyItem(productName: '富邦人壽美好人生終身壽險', coverageRole: 'main', premium: 30000),
        ScannedPolicyItem(productName: '富邦人壽癌症健康附約', coverageRole: 'rider', premium: 1200),
      ]);
      final RetakeResult result = PolicyRetake.compare(first, retake);
      expect(result.mismatchText, isNull);
      expect(result.newItems.length, 1);
      expect(result.duplicateCount, 1);
      expect(result.conflicts.length, 1);

      PolicyRetake.apply(first, retake, result);
      expect(first.items.length, 3);
      expect(first.items.last.addedByRetake, isTrue);
      expect(first.effectiveDate, DateTime(2024, 3, 1));
      expect(first.items[1].retakeAlternative?.planOrAmount, '計畫二');
      PolicyRetake.useRetakeValue(first.items[1]);
      expect(first.items[1].planOrAmount, '計畫二');
      expect(first.items[1].retakeAlternative, isNull);

      final ScannedPolicy otherPolicy = ScannedPolicy(companyCode: 'fubon', policyNumber: 'B456', items: []);
      expect(PolicyRetake.compare(first, otherPolicy).mismatchText, contains('A123 → B456'));
    });

    testWidgets('確認畫面：補拍新增標示、金額不同可改用補拍的', (WidgetTester tester) async {
      final ScannedPolicyItem changed = ScannedPolicyItem(productName: '富邦人壽實支實付醫療附約', coverageRole: 'rider', planOrAmount: '計畫三');
      changed.retakeAlternative = ScannedPolicyItem(productName: '富邦人壽實支實付醫療附約', planOrAmount: '計畫二');
      final ScannedPolicyItem added = ScannedPolicyItem(productName: '富邦人壽癌症健康附約', coverageRole: 'rider');
      added.addedByRetake = true;
      int usedIndex = -1;
      await pumpInWidth(
        tester,
        375,
        ScanReviewPanel(
          customerName: '王測一',
          policy: ScannedPolicy(companyCode: 'fubon', items: [changed, added]),
          status: PolicyStatus.active,
          isSaving: false,
          onEditItem: (_) {},
          onRemoveItem: (_) {},
          onApplySuggestion: (_) {},
          onAddItem: () {},
          onRetake: () {},
          onUseRetakeValue: (int index) => usedIndex = index,
          onStatusChanged: (_) {},
          onRescan: () {},
          onSave: () {},
        ),
      );
      expect(find.text('補拍新增'), findsOneWidget);
      expect(find.textContaining('補拍讀到：計畫二'), findsOneWidget);
      expect(find.textContaining('補拍讀到的金額或計畫不一樣'), findsOneWidget);
      expect(find.text('補拍漏掉的'), findsOneWidget);
      await tester.tap(find.text('改用補拍的'));
      expect(usedIndex, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('確認畫面：照片沒切成兩半、整張辨識時黃色提醒核對項數', (WidgetTester tester) async {
      final ScannedPolicy policy = ScannedPolicy(
        companyCode: 'fubon',
        items: [ScannedPolicyItem(productName: '富邦人壽測試壽險', coverageRole: 'main')],
      );
      policy.sentWholePhoto = true;
      await pumpInWidth(
        tester,
        375,
        ScanReviewPanel(
          customerName: '王測一',
          policy: policy,
          status: PolicyStatus.active,
          isSaving: false,
          onEditItem: (_) {},
          onRemoveItem: (_) {},
          onApplySuggestion: (_) {},
          onAddItem: () {},
          onRetake: () {},
          onUseRetakeValue: (_) {},
          onStatusChanged: (_) {},
          onRescan: () {},
          onSave: () {},
        ),
      );
      expect(find.textContaining('整張辨識'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('重複保單：提醒並可以選「仍要存入」或「取消」', (WidgetTester tester) async {
      bool? confirmed;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => confirmed = await showScanDuplicateDialog(
              context,
              customerName: '手機測一',
              policyNumber: 'TEST-CA-0001',
              existingPolicy: ExistingPolicyInfo(itemCount: 3, firstSavedAt: DateTime(2026, 10, 24)),
            ),
            child: const Text('打開'),
          ),
        ),
      ));
      await tester.tap(find.text('打開'));
      await tester.pumpAndSettle();
      expect(find.text('這份保單可能已經存過'), findsOneWidget);
      expect(find.textContaining('3 項，10/24 存入', findRichText: true), findsOneWidget);
      await tester.tap(find.text('仍要存入'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });

  group('照片切兩半、電子保單讀文字（2026-10-25）', () {
    test('切兩半重疊處重複列出的商品只留一筆', () {
      final ScannedPolicy policy = ScannedPolicy(items: [
        ScannedPolicyItem(productName: '南山人壽珍安康2意外傷害保險附約', premium: 1410),
        ScannedPolicyItem(productName: '南山人壽意外骨折暨傷害醫療保險附約', premium: 455),
        ScannedPolicyItem(productName: '南山人壽 意外骨折暨傷害醫療保險附約', premium: 455),
        ScannedPolicyItem(productName: '南山人壽愛家保要保人豁免保險費附約', premium: 380),
      ]);
      PolicyScanMerge.removeDuplicateItems(policy);
      expect(policy.items.length, 3);
    });

    test('名稱一樣但保費不同，當成兩筆（不亂刪）', () {
      final ScannedPolicy policy = ScannedPolicy(items: [
        ScannedPolicyItem(productName: '國泰人壽新金骨力傷害暨兒童意外骨折保險附約', premium: 71),
        ScannedPolicyItem(productName: '國泰人壽新金骨力傷害暨兒童意外骨折保險附約', premium: 120),
      ]);
      PolicyScanMerge.removeDuplicateItems(policy);
      expect(policy.items.length, 2);
    });

    testWidgets('電子保單有文字時，上傳畫面提示「直接讀取文字」', (WidgetTester tester) async {
      await pumpInWidth(
        tester,
        1200,
        ScanCapturePanel(
          isMobileDevice: false,
          images: [base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=')],
          maximumImageCount: 3,
          isReadingPdfText: true,
          onTakePhoto: () {},
          onUploadFile: () {},
          onRemoveImage: (_) {},
          onStartRecognize: () {},
        ),
      );
      expect(find.textContaining('直接讀取文字'), findsOneWidget);
    });
  });
}
