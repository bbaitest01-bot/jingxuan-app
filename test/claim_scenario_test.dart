import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/benefit_item_service.dart';
import 'package:insurance_helper/services/benefit_plan_service.dart';
import 'package:insurance_helper/services/benefit_trial_calculator.dart';
import 'package:insurance_helper/services/scenario/claim_scenario.dart';
import 'package:insurance_helper/services/scenario/claim_scenario_calculator.dart';
import 'package:insurance_helper/services/scenario/formula_amount.dart';
import 'package:insurance_helper/services/scenario/scenario_item_matcher.dart';

InsuranceBenefitItem buildItem(String name, String? formula) {
  return InsuranceBenefitItem(productId: 'p', itemOrder: 1, itemKey: name, itemName: name, formula: formula, sourceExcerpt: '');
}

// 真實限額表：富邦佳實在 計劃2（手術另外 6 萬、每次住院總上限 30 萬）
const InsuranceBenefitPlan fubonPlan2 = InsuranceBenefitPlan(
  productId: 'fubon',
  planCode: '計劃2',
  planOrder: 2,
  benefitType: InsuranceBenefitPlan.typeItemized,
  roomDailyLimit: 2000,
  hospitalExpenseLimit: 200000,
  surgeryLimit: 60000,
  perAdmissionTotalLimit: 300000,
);

// 真實限額表：國泰新實全心意 M20（手術含在醫療費用 20 萬裡）
const InsuranceBenefitPlan cathayM20 = InsuranceBenefitPlan(
  productId: 'cathay',
  planCode: 'M20',
  planOrder: 2,
  benefitType: InsuranceBenefitPlan.typeDeductible,
  roomDailyLimit: 2000,
  hospitalExpenseLimit: 200000,
  hospitalExpenseIncludesSurgery: true,
);

int totalOf(ClaimScenarioInput input, {InsuranceBenefitPlan? plan, List<InsuranceBenefitItem> items = const [],
    BenefitTrialInput trial = const BenefitTrialInput()}) {
  return ClaimScenarioCalculator.calculate(input: input, plan: plan, items: items, trialInput: trial).total;
}

void main() {
  group('住院：實支實付（真實限額表）', () {
    test('沒開刀時佳實在、新實全心意一樣 16 萬', () {
      const ClaimScenarioInput noSurgery = ClaimScenarioInput(surgeryExpense: 0);
      expect(totalOf(noSurgery, plan: fubonPlan2), 160000);
      expect(totalOf(noSurgery, plan: cathayM20), 160000);
    });

    test('開刀自費 10 萬：佳實在手術另外給 6 萬＝22 萬；新實全心意共用 20 萬上限＝21 萬', () {
      const ClaimScenarioInput withSurgery = ClaimScenarioInput();
      expect(totalOf(withSurgery, plan: fubonPlan2), 220000);
      expect(totalOf(withSurgery, plan: cathayM20), 210000);
    });

    test('超過每次住院總上限會扣回', () {
      // 病房 1 萬＋醫療 20 萬＋手術 6 萬＝27 萬，總上限只有 25 萬 → 給 25 萬
      const InsuranceBenefitPlan lowTotalPlan = InsuranceBenefitPlan(
        productId: 'test',
        planCode: '測試',
        planOrder: 1,
        benefitType: InsuranceBenefitPlan.typeItemized,
        roomDailyLimit: 2000,
        hospitalExpenseLimit: 200000,
        surgeryLimit: 60000,
        perAdmissionTotalLimit: 250000,
      );
      const ClaimScenarioInput expensive = ClaimScenarioInput(medicalExpense: 500000, surgeryExpense: 500000);
      expect(totalOf(expensive, plan: lowTotalPlan), 250000);
    });

    test('買兩張（副本理賠）金額乘 2，只有實支實付可以選張數', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
          input: const ClaimScenarioInput(), plan: fubonPlan2, items: const [], trialInput: const BenefitTrialInput());
      expect(result.canBuyMultipleCopies, isTrue);
      expect(result.timesCopies(2).total, 440000);
    });
  });

  group('住院：日額型', () {
    test('日額 2,000 × 5 天；住院手術依附表算不出來，列在沒加進去', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(),
        plan: null,
        items: [buildItem('住院醫療保險金', '日額 × 天數'), buildItem('住院手術醫療保險金', '日額 × 附表倍數')],
        trialInput: const BenefitTrialInput(dailyAmount: 2000),
      );
      expect(result.total, 10000);
      expect(result.notCounted.single, contains('附表'));
      expect(result.canBuyMultipleCopies, isFalse);
    });

    test('沒填日額時提醒先填試算', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
          input: const ClaimScenarioInput(), plan: null, items: [buildItem('住院醫療保險金', '日額 × 天數')],
          trialInput: const BenefitTrialInput());
      expect(result.notCounted.single, contains('先在試算填日額'));
    });
  });

  group('一次給的情境', () {
    final List<InsuranceBenefitItem> criticalItems = [
      buildItem('輕度重大疾病保險金', '保額 × 5%'),
      buildItem('重度重大疾病保險金', '保額 × 1'),
    ];
    const BenefitTrialInput million = BenefitTrialInput(coverageAmount: 1000000);

    test('重大疾病：重度給 100 萬、輕度給 5 萬', () {
      expect(totalOf(const ClaimScenarioInput(type: ClaimScenarioType.criticalIllness), items: criticalItems, trial: million), 1000000);
      expect(
          totalOf(const ClaimScenarioInput(type: ClaimScenarioType.criticalIllness, isSevereCriticalIllness: false),
              items: criticalItems, trial: million),
          50000);
    });

    test('重大疾病：沒寫輕重的算重度；好幾張疾病清單只算最高的一項', () {
      final ClaimScenarioResult mild = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(type: ClaimScenarioType.criticalIllness, isSevereCriticalIllness: false),
        plan: null,
        items: [buildItem('輕度重大疾病保險金', '保額 × 20%'), buildItem('重大疾病保險金', '保額 × 1.3')],
        trialInput: million,
      );
      expect(mild.total, 200000);
      final ClaimScenarioResult severe = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(type: ClaimScenarioType.criticalIllness),
        plan: null,
        items: [buildItem('特定重大傷病保險金', '保額 × 20%'), buildItem('特定傷病保險金', '保額 × 1')],
        trialInput: million,
      );
      expect(severe.total, 1000000);
      expect(severe.notCounted.single, contains('另一張疾病清單'));
    });

    test('癌症：特定癌症不算進一般確診，列在沒加進去', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(type: ClaimScenarioType.cancer, isSevereCancer: false),
        plan: null,
        items: [buildItem('初次罹患癌症(初期)或癌症(輕度)保險金', '保額 × 20%'), buildItem('初次罹患特定癌症保險金', '保額 × 60%')],
        trialInput: million,
      );
      expect(result.total, 200000);
      expect(result.notCounted.single, contains('特定癌症'));
    });

    test('長照：「保額 × 12」是一年給一次，照顧 24 個月給 2 次', () {
      expect(
          totalOf(const ClaimScenarioInput(type: ClaimScenarioType.longTermCare, careMonths: 24),
              items: [buildItem('長期照顧分期保險金', '保額 × 12')], trial: const BenefitTrialInput(coverageAmount: 30000)),
          720000);
    });

    test('意外：失能 6 級時，第一級才給和交通意外加給的都不算', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(type: ClaimScenarioType.accident, disabilityLevel: 6),
        plan: null,
        items: [
          buildItem('意外事故失能保險金', '保額 × 附表比例'),
          buildItem('水陸交通意外事故第一級失能保險金', '保額 × 2'),
          buildItem('航空交通意外事故失能保險金', '保額 × 3 × 附表比例'),
        ],
        trialInput: million,
      );
      expect(result.total, 500000);
      expect(result.notCounted.single, contains('特定意外'));
    });

    test('身故：疾病身故不算意外身故；意外身故兩個都給', () {
      final List<InsuranceBenefitItem> deathItems = [
        buildItem('身故保險金', '保額 × 1'),
        buildItem('意外身故保險金', '保額 × 1'),
      ];
      expect(totalOf(const ClaimScenarioInput(type: ClaimScenarioType.death), items: deathItems, trial: million), 1000000);
      expect(totalOf(const ClaimScenarioInput(type: ClaimScenarioType.death, isAccidentalDeath: true), items: deathItems, trial: million),
          2000000);
    });

    test('癌症：第 2 年起的算法，記下條件', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
        input: const ClaimScenarioInput(type: ClaimScenarioType.cancer, isSevereCancer: false),
        plan: null,
        items: [buildItem('初次罹患癌症(初期)或癌症(輕度)保險金', '第2年起：保額 × 20%（第1年內：保費 × 1）')],
        trialInput: million,
      );
      expect(result.total, 200000);
      expect(result.lines.single.note, contains('第2年起'));
    });

    test('長照：分期保險金按月給 × 12 個月', () {
      expect(
          totalOf(const ClaimScenarioInput(type: ClaimScenarioType.longTermCare),
              items: [buildItem('長期照顧分期保險金', '保額 × 1')], trial: const BenefitTrialInput(coverageAmount: 30000)),
          360000);
    });

    test('意外：失能 6 級＝保額 × 50%；完全失能只有 1 級給', () {
      final List<InsuranceBenefitItem> accidentItems = [
        buildItem('意外事故失能保險金', '保額 × 附表比例'),
        buildItem('完全失能保險金', '保額 × 1'),
      ];
      expect(totalOf(const ClaimScenarioInput(type: ClaimScenarioType.accident, disabilityLevel: 6), items: accidentItems, trial: million),
          500000);
      expect(totalOf(const ClaimScenarioInput(type: ClaimScenarioType.accident, disabilityLevel: 1), items: accidentItems, trial: million),
          2000000);
    });

    test('取較高：只填保額時用保額，還有保單價值時算「至少」', () {
      final FormulaAmount amount = FormulaAmountCalculator.calculate('取較高：保額 × 1／保單價值', million);
      expect(amount.amount, 1000000);
      expect(amount.isMinimum, isTrue);
    });
  });

  group('沒有資料的商品', () {
    test('豁免保費這類沒有給付項目的，說明原因', () {
      final ClaimScenarioResult result = ClaimScenarioCalculator.calculate(
          input: const ClaimScenarioInput(), plan: null, items: const [], trialInput: const BenefitTrialInput());
      expect(result.emptyReason, contains('豁免保費'));
    });
  });

  // 拿真實 1,725 個給付項目跑一遍：每個情境都要分到項目，而且不會當掉
  test('真實給付項目：六個情境都有對到項目', () {
    final File file = File('tool/benefit_items/benefit_items_auto.json');
    final List<dynamic> products = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final Map<String, int> matchedByScenario = {};
    for (final String type in ClaimScenarioType.labels.keys) {
      final ClaimScenarioInput input = ClaimScenarioInput(type: type, disabilityLevel: 6);
      for (final dynamic product in products) {
        for (final dynamic item in (product as Map<String, dynamic>)['items'] as List<dynamic>) {
          final Map<String, dynamic> data = item as Map<String, dynamic>;
          final ScenarioItemUse use = ScenarioItemMatcher.useOf(data['item_name'] as String, data['formula'] as String?, input);
          if (use.isIncluded) matchedByScenario[type] = (matchedByScenario[type] ?? 0) + 1;
          FormulaAmountCalculator.calculate(data['formula'] as String?, const BenefitTrialInput(coverageAmount: 1000000, dailyAmount: 1000, units: 1, annualPremium: 10000));
        }
      }
    }
    for (final String type in ClaimScenarioType.labels.keys) {
      expect(matchedByScenario[type] ?? 0, greaterThan(10), reason: type);
    }
  });
}
