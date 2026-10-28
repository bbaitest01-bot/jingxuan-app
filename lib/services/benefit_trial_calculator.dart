import 'package:intl/intl.dart';

import 'benefit_item_service.dart';

/// 比較頁「試算」：業務員填的保額、日額、單位數、年繳保費（只在這次比較用，不存檔）
class BenefitTrialInput {
  // 保額（元）；畫面上輸入的是萬元，存進來前已經乘 10000
  final int? coverageAmount;
  // 住院日額（元／天）
  final int? dailyAmount;
  // 投保單位數（南山、富邦部分商品按單位賣）
  final int? units;
  // 年繳保費（元）
  final int? annualPremium;

  const BenefitTrialInput({this.coverageAmount, this.dailyAmount, this.units, this.annualPremium});

  static const BenefitTrialInput empty = BenefitTrialInput();

  bool get isEmpty => coverageAmount == null && dailyAmount == null && units == null && annualPremium == null;
}

/// 這款商品的試算要問哪些數字（看給付項目的算法用到什麼）
class BenefitTrialFields {
  final bool needsCoverageAmount;
  final bool needsDailyAmount;
  final bool needsUnits;

  const BenefitTrialFields({
    required this.needsCoverageAmount,
    required this.needsDailyAmount,
    required this.needsUnits,
  });
}

/// 把給付項目的算法套上業務員填的數字，算出真正金額
class BenefitTrialCalculator {
  static final RegExp _baseMultiplierPattern = RegExp(r'(保額|日額|保費) × ([\d.]+)(%?)(?:～([\d.]+)%)?');
  static final RegExp _moneyPattern = RegExp(r'(每日|每次|每年|每月)?([\d,]+) 元');

  /// 看這款商品的項目用到保額、日額還是單位
  static BenefitTrialFields fieldsFor(List<InsuranceBenefitItem> items) {
    bool needsCoverageAmount = false;
    bool needsDailyAmount = false;
    bool needsUnits = false;
    for (final InsuranceBenefitItem item in items) {
      final String formula = item.formula ?? '';
      if (formula.contains('保額')) needsCoverageAmount = true;
      if (formula.contains('日額')) needsDailyAmount = true;
      if (formula.contains('每單位')) needsUnits = true;
    }
    return BenefitTrialFields(
      needsCoverageAmount: needsCoverageAmount,
      needsDailyAmount: needsDailyAmount,
      needsUnits: needsUnits,
    );
  }

  /// 「保額 × 10%」＋保額 50 萬 →「5 萬元」；
  /// 「第2年起：保額 × 1（第1年內：保費 × 1.1）」→「第2年起：50 萬元（第1年內：13,200 元）」；
  /// 算法裡的數字一個都算不出來（沒填、或是附表比例）回傳 null
  static String? amountText(String formula, BenefitTrialInput input) {
    bool replacedAny = false;

    // 保額／日額／保費 × 倍數（含 1%～115% 的範圍）
    String result = formula.replaceAllMapped(_baseMultiplierPattern, (Match match) {
      final int? baseAmount = _baseAmountOf(match.group(1)!, input);
      if (baseAmount == null) {
        return match.group(0)!;
      }
      final bool isPercent = match.group(3) == '%';
      final double firstMultiplier = double.parse(match.group(2)!);
      final String? rangeEnd = match.group(4);
      replacedAny = true;
      if (rangeEnd != null) {
        final String low = formatMoney(baseAmount * firstMultiplier / 100);
        final String high = formatMoney(baseAmount * double.parse(rangeEnd) / 100);
        return '$low～$high';
      }
      double amount = baseAmount * firstMultiplier;
      if (isPercent) {
        amount = amount / 100;
      }
      return formatMoney(amount);
    });

    // 每單位 X 元 × 單位數；「每單位 每日1,200 元（第91日起 每日1,800 元）」括號裡的金額也是每單位，一起乘
    final int? units = input.units;
    if (units != null && result.startsWith('每單位 ')) {
      result = result.substring('每單位 '.length).replaceAllMapped(_moneyPattern, (Match match) {
        replacedAny = true;
        final String period = match.group(1) ?? '';
        final int perUnit = int.parse(match.group(2)!.replaceAll(',', ''));
        return '$period${formatMoney((perUnit * units).toDouble())}';
      });
    }

    if (!replacedAny) {
      return null;
    }
    // 「5,000 元 × 天數」讀起來改成「每天 5,000 元」
    result = result.replaceAllMapped(RegExp(r'([\d,.萬～]+ ?元) × 天數'), (Match match) => '每天 ${match.group(1)}');
    return result;
  }

  static int? _baseAmountOf(String base, BenefitTrialInput input) {
    switch (base) {
      case '保額':
        return input.coverageAmount;
      case '日額':
        return input.dailyAmount;
      case '保費':
        return input.annualPremium;
    }
    return null;
  }

  /// 10 萬以上寫「50 萬元」「12.5 萬元」，以下寫「13,200 元」
  static String formatMoney(double amount) {
    final int rounded = amount.round();
    if (rounded >= 100000) {
      final double tenThousands = rounded / 10000;
      String text = tenThousands.toStringAsFixed(1);
      if (text.endsWith('.0')) {
        text = text.substring(0, text.length - 2);
      }
      return '$text 萬元';
    }
    return '${NumberFormat('#,###').format(rounded)} 元';
  }
}
