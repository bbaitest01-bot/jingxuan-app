import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/benefit_item_service.dart';
import 'package:insurance_helper/services/benefit_trial_calculator.dart';

void main() {
  group('比較頁試算', () {
    const BenefitTrialInput input = BenefitTrialInput(
      coverageAmount: 500000,
      dailyAmount: 2000,
      units: 3,
      annualPremium: 12000,
    );

    test('保額、日額、保費乘倍數算出金額', () {
      expect(BenefitTrialCalculator.amountText('保額 × 10%', input), '50,000 元');
      expect(BenefitTrialCalculator.amountText('保額 × 1', input), '50 萬元');
      expect(BenefitTrialCalculator.amountText('日額 × 3 × 天數', input), '每天 6,000 元');
    });

    test('分情況兩段都算；範圍算出上下限', () {
      expect(
        BenefitTrialCalculator.amountText('第2年起：保額 × 1（第1年內：保費 × 1.1）', input),
        '第2年起：50 萬元（第1年內：13,200 元）',
      );
      expect(BenefitTrialCalculator.amountText('保額 × 30%～115%（依投保第幾年）', input), '15 萬元～57.5 萬元（依投保第幾年）');
    });

    test('每單位金額乘單位數', () {
      expect(BenefitTrialCalculator.amountText('每單位 50,000 元', input), '15 萬元');
      expect(BenefitTrialCalculator.amountText('每單位 每日1,200 元（第91日起 每日1,800 元）', input), '每日3,600 元（第91日起 每日5,400 元）');
    });

    test('沒填數字或附表比例算不出來回傳 null', () {
      expect(BenefitTrialCalculator.amountText('保額 × 10%', BenefitTrialInput.empty), isNull);
      expect(BenefitTrialCalculator.amountText('保額 × 附表比例', input), isNull);
    });

    test('依項目算法決定要問保額、日額或單位', () {
      const List<InsuranceBenefitItem> items = [
        InsuranceBenefitItem(productId: 'p', itemOrder: 1, itemKey: '住院', itemName: '住院', formula: '日額 × 天數', sourceExcerpt: ''),
        InsuranceBenefitItem(productId: 'p', itemOrder: 2, itemKey: '癌症', itemName: '癌症', formula: '每單位 50,000 元', sourceExcerpt: ''),
      ];
      final BenefitTrialFields fields = BenefitTrialCalculator.fieldsFor(items);
      expect(fields.needsDailyAmount, isTrue);
      expect(fields.needsUnits, isTrue);
      expect(fields.needsCoverageAmount, isFalse);
    });
  });
}
