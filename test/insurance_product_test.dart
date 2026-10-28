import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/screens/policy_comparison_screen.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/insurance_product_service.dart';
import 'package:insurance_helper/widgets/customer_policy_widgets.dart';
import 'package:insurance_helper/widgets/insurance_product_card.dart';

/// 依 insurance_products 欄位做一筆測試商品
InsuranceProduct buildProduct({
  String id = 'p1',
  String companyName = '國泰人壽',
  String? productCode = 'C64',
  String productName = '國泰人壽測試醫療終身保險',
  String productKind = 'main',
  String? insuranceType = 'medical',
  String? clauseUrl = 'https://www.cathaylife.com.tw/clause.pdf',
}) {
  return InsuranceProduct.fromJson({
    'id': id,
    'company_code': 'cathay',
    'company_name': companyName,
    'product_code': productCode,
    'product_name': productName,
    'product_kind': productKind,
    'insurance_type': insuranceType,
    'source_category': '壽險、年金險、健康險主約商品',
    'approval_date': '2022-09-29',
    'approval_number': '國壽字第1110090697號',
    'approval_history': '111.09.29國壽字第1110090697號函備查',
    'clause_url': clauseUrl,
    'source_url': 'https://www.cathaylife.com.tw/list.pdf',
  });
}

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  group('InsuranceProduct 資料轉換', () {
    test('讀入資料庫欄位，險種、主約／附約翻成中文', () {
      final InsuranceProduct product = buildProduct(insuranceType: 'critical_illness', productKind: 'rider');
      expect(product.insuranceTypeLabel, '重大疾病');
      expect(product.productKindLabel, '附約');
      expect(product.approvalDate, DateTime(2022, 9, 29));
      expect(formatApprovalDate(product.approvalDate), '2022/09/29');
    });

    test('沒有代碼顯示「無代碼」；沒有條款連結就不能開', () {
      final InsuranceProduct product = buildProduct(productCode: null, clauseUrl: null, insuranceType: null);
      expect(product.displayCode, '無代碼');
      expect(product.hasClauseUrl, isFalse);
      expect(product.insuranceTypeLabel, '其他');
      expect(formatApprovalDate(null), '—');
    });

    test('搜尋關鍵字會拿掉逗號、括號等會破壞查詢條件的符號', () {
      expect(InsuranceProductService.splitKeywords('  國泰  醫療 '), ['國泰', '醫療']);
      expect(InsuranceProductService.splitKeywords('a,b(c)%d'), ['a', 'b', 'c', 'd']);
      expect(InsuranceProductService.splitKeywords('   '), isEmpty);
    });

    test('分頁：784 筆、每頁 12 筆是 66 頁；沒有資料時算 1 頁', () {
      expect(const InsuranceProductSearchResult(products: [], totalCount: 784, page: 1, pageSize: 12).totalPages, 66);
      expect(const InsuranceProductSearchResult(products: [], totalCount: 0, page: 1, pageSize: 12).totalPages, 1);
    });
  });

  group('客戶保單沒有限額時不補假數字', () {
    test('讀回沒有限額的保單：文字留空、不算有限額資料', () {
      final CustomerEnrolledPolicy policy = CustomerEnrolledPolicy.fromJson({
        'id': 'cp1',
        'customer_id': 'c1',
        'product_name': '國泰人壽測試醫療終身保險',
        'company_name': '國泰人壽',
        'category': '醫療',
        'room_limit': null,
        'benefits_json': <String, dynamic>{},
      });
      expect(policy.roomLimit, '');
      expect(policy.roomDailyValue, isNull);
      expect(policy.hasLimitData, isFalse);
      expect(limitTextOrNotReady(policy.roomLimit), '建置中');
    });

    test('保障總額只算有限額資料的保單，全部沒有時不判斷缺口', () {
      final CustomerEnrolledPolicy withoutLimit = CustomerEnrolledPolicy.fromJson({
        'id': 'cp1',
        'customer_id': 'c1',
        'category': '醫療',
        'benefits_json': <String, dynamic>{},
      });
      final CustomerBenefitSummary summary =
          CustomerPolicyService().calculateCustomerBenefitSummary([withoutLimit]);
      expect(summary.countedPolicyCount, 0);
      expect(summary.policiesWithoutLimitCount, 1);
      expect(summary.totalRoomDaily, 0);
      expect(summary.hasCriticalGap, isFalse);
    });
  });

  group('資料來源', () {
    test('有來源網址加 ↗ 表示可點；讀得到官網最後確認日期', () {
      final InsuranceProduct product = InsuranceProduct.fromJson({
        'id': 'p1',
        'company_name': '國泰人壽',
        'product_name': '國泰人壽測試',
        'source_url': 'https://www.cathaylife.com.tw/official/laws-policies',
        'last_seen_at': '2026-10-26T02:00:00+00:00',
      });
      expect(productSourceLabel(product), '國泰人壽官網・資訊公開 ↗');
      expect(formatApprovalDate(product.lastSeenAt), '2026/10/26');
    });
  });

  group('官方條款連結', () {
    test('富邦條款改經過雲端函式 clause-pdf，其他公司直接開', () {
      const String restUrl = 'https://example.supabase.co/rest/v1';
      const String fubonUrl = 'https://www.fubon.com/life/api/v1/files/12781/download/a.pdf';
      final Uri fubonUri = clauseOpenUri(fubonUrl, restUrl);
      expect(fubonUri.path, '/functions/v1/clause-pdf');
      expect(fubonUri.queryParameters['url'], fubonUrl);

      const String cathayUrl = 'https://www.cathaylife.com.tw/official/files/M26.pdf';
      expect(clauseOpenUri(cathayUrl, restUrl).toString(), cathayUrl);
    });
  });

  group('保單比較畫面', () {
    testWidgets('比較的商品都沒有限額表時不顯示實支實付區塊，下方說明不是保費；試算按鈕按下只提示建置中', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        PolicyComparisonScreen(initialProducts: [
          buildProduct(),
          buildProduct(id: 'p2', companyName: '富邦人壽', productCode: 'FPF', productName: '富邦人壽測試壽險', insuranceType: 'life'),
        ]),
      );

      // 兩款測試商品都沒有限額表 → 整個實支實付區塊不顯示（第 5 階段 D 第 2 層）；
      // 舊的「比價欄位建置中」、2-2-7、收據兩列已拿掉（D14）
      expect(find.text('理賠限額（實支實付）'), findsNothing);
      expect(find.text('不是實支實付（沒有限額表）'), findsNothing);
      expect(find.text('比價欄位建置中'), findsNothing);
      expect(find.text('健保 2-2-7 限制'), findsNothing);
      expect(find.textContaining('不是保費'), findsOneWidget);
      expect(find.text('國壽字第1110090697號'), findsNWidgets(2));

      await tester.tap(find.text('全真醫療單據試算（建置中）').first);
      // 提示訊息在下一幀才加到畫面上
      await tester.pump();
      await tester.pump();
      expect(find.text('試算需要理賠限額資料，目前建置中'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('只有一款時是「商品資料」頁：沒有只看差異、組合精算、移除按鈕', (WidgetTester tester) async {
      await pumpScreen(tester, PolicyComparisonScreen(initialProducts: [buildProduct()]));

      expect(find.text('商品資料'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('組合包聯合精算'), findsNothing);
      expect(find.byTooltip('移除此商品'), findsNothing);
      expect(find.text('官方條款 PDF'), findsOneWidget);
      expect(find.text('加到客戶'), findsOneWidget);
    });

    testWidgets('「只看差異」只留下兩款不同的列', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        PolicyComparisonScreen(initialProducts: [
          buildProduct(),
          buildProduct(id: 'p2', companyName: '富邦人壽', productCode: 'FPF', productName: '富邦人壽測試壽險', insuranceType: 'life'),
        ]),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // 公司、代碼、險種不同 → 顯示；文號相同、兩款都沒有限額表 → 隱藏
      expect(find.text('保險公司'), findsNWidgets(2));
      expect(find.text('險種'), findsNWidgets(2));
      expect(find.text('核准文號'), findsNothing);
      expect(find.text('不是實支實付（沒有限額表）'), findsNothing);
    });
  });

  group('商品卡片', () {
    testWidgets('顯示代碼、險種、主約／附約、首次核准與查看條款', (WidgetTester tester) async {
      bool tapped = false;
      await pumpScreen(
        tester,
        Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: InsuranceProductCard(
              product: buildProduct(),
              isSelected: false,
              onToggleSelected: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('C64'), findsOneWidget);
      expect(find.text('醫療'), findsOneWidget);
      expect(find.text('主約'), findsOneWidget);
      expect(find.text('2022/09/29'), findsOneWidget);
      expect(find.text('查看條款'), findsOneWidget);

      await tester.tap(find.text('國泰人壽測試醫療終身保險'));
      expect(tapped, isTrue);
    });
  });
}
