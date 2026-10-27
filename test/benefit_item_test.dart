import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/benefit_item_service.dart';
import 'package:insurance_helper/widgets/benefit_item_comparison.dart';

InsuranceBenefitItem buildItem(String productId, String itemKey, {String? formula}) {
  return InsuranceBenefitItem(
    productId: productId,
    itemOrder: 1,
    itemKey: itemKey,
    itemName: '$itemKey保險金',
    formula: formula,
    sourceExcerpt: '條款原文',
  );
}

void main() {
  group('給付項目比較', () {
    final List<InsuranceBenefitItem> cathayItems = [
      buildItem('cathay', '初次罹患癌症（重度）'),
      buildItem('cathay', '癌症（重度）標靶藥物治療補助', formula: '保額 × 10%'),
    ];
    final List<InsuranceBenefitItem> nanshanItems = [
      buildItem('nanshan', '初次罹患癌症（重度）', formula: '每單位 50,000 元'),
      buildItem('nanshan', '乳癌護理', formula: '每單位 50,000 元'),
    ];

    test('列依第一款、第二款的條款順序合併，重複的只留一次', () {
      final List<String> keys = BenefitItemService.orderedItemKeys([cathayItems, nanshanItems]);
      expect(keys, ['初次罹患癌症（重度）', '癌症（重度）標靶藥物治療補助', '乳癌護理']);
    });

    test('格子文字：有算法顯示算法、沒算法請看原文、沒有這項顯示沒有', () {
      expect(benefitItemCellText(cathayItems, '癌症（重度）標靶藥物治療補助'), '保額 × 10%\n（每萬元保額可領 1,000 元）');
      expect(benefitItemCellText(cathayItems, '初次罹患癌症（重度）'), benefitItemSeeClauseText);
      expect(benefitItemCellText(cathayItems, '乳癌護理'), benefitItemNotIncludedText);
    });

    test('算法換成金額：保額每 1 萬、日額每 1,000；每單位金額和附表比例不換算', () {
      expect(benefitItemExampleText('保額 × 12'), '每萬元保額可領 120,000 元');
      expect(benefitItemExampleText('日額 × 3 × 天數'), '日額 1,000 元，每天可領 3,000 元');
      expect(benefitItemExampleText('日額 × 50%'), '日額 1,000 元，可領 500 元');
      expect(benefitItemExampleText('每單位 50,000 元'), isNull);
      expect(benefitItemExampleText('保額 × 附表比例'), isNull);
      expect(benefitItemExampleText('保額 × 1%～105%（依投保第幾年）'), isNull);
      expect(benefitItemExampleText('第2年起：保額 × 5（第1年內：保額 × 50%）'), '每萬元保額可領 50,000 元');
    });

    test('商品沒有給付項目資料時顯示「—」，不說它沒有', () {
      expect(benefitItemCellText(const [], '乳癌護理'), benefitItemNoDataText);
    });

    test('從資料庫的一列轉成項目', () {
      final InsuranceBenefitItem item = InsuranceBenefitItem.fromJson({
        'product_id': 'p1',
        'item_order': 2,
        'item_key': '住院日額',
        'item_name': '住院日額保險金',
        'formula': null,
        'source_excerpt': '本公司按住院日數…',
      });
      expect(item.itemOrder, 2);
      expect(item.formula, isNull);
      expect(item.sourceExcerpt, '本公司按住院日數…');
    });
  });
}
