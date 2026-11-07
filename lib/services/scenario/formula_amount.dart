import '../benefit_trial_calculator.dart';

/// 一個給付項目算出來的金額
class FormulaAmount {
  // 算出來的金額（還沒乘天數）；算不出來是 null
  final int? amount;
  // 要乘天數（「日額 × 天數」「每單位 每日 1,200 元」）
  final bool isPerDay;
  // 算不出來的原因，或算得出來但要提醒的事（「第 2 年起」「未含增額係數」）
  final String? note;
  // 這是「至少」：取較高還有保單價值、或比例依投保年數
  final bool isMinimum;

  const FormulaAmount({this.amount, this.isPerDay = false, this.note, this.isMinimum = false});

  const FormulaAmount.unknown(String reason) : this(note: reason);

  bool get isKnown => amount != null;
}

/// 把給付項目的算法（「保額 × 20%」「日額 × 天數」「取較高：保額 × 1／保費 × 1.06」）
/// 套上試算填的保額、日額、單位、年繳保費，算出數字
///
/// 只算查得到規則的寫法；「分情況（看原文）」「依附表倍數」這類回傳原因，畫面列在「算不出來」
class FormulaAmountCalculator {
  // 「保額 × 20%」「日額 × 3」「保費 × 1.06」，後面可能接「× 天數」
  static final RegExp _baseTimesPattern = RegExp(r'^(保額|日額|保費) × ([\d.]+)(%?)( × ([\d.]+)%?)?( × 天數)?$');
  // 「保額 × 5%～20%（依投保第幾年）」：取最低的
  static final RegExp _rangePattern = RegExp(r'^保額 × ([\d.]+)%～([\d.]+)%');
  // 「每單位 1,000 元」「每單位 每日1,200 元」「每單位 1,000 元 × 天數」
  static final RegExp _perUnitPattern = RegExp(r'^每單位 (每日|每次|每年)?([\d,]+) 元( × 天數)?$');
  // 「每次 3,000 元」
  static final RegExp _fixedPattern = RegExp(r'^每次 ([\d,]+) 元$');
  // 「50萬」
  static final RegExp _tenThousandsPattern = RegExp(r'^([\d.]+)萬$');
  // 「第2年起：」「續保後：」「65歲以上：」這類前綴
  static final RegExp _conditionPrefixPattern = RegExp(r'^(第\d+年起|續保後|\d+歲以上)：');

  /// [disabilityRatio] 只有意外失能情境會給（「保額 × 附表比例」用失能等級的比例）
  static FormulaAmount calculate(
    String? formula,
    BenefitTrialInput input, {
    double? disabilityRatio,
  }) {
    String text = (formula ?? '').trim();
    if (text.isEmpty) return const FormulaAmount.unknown('條款沒有寫出固定算法，請看原文');
    if (text.contains('看原文')) return const FormulaAmount.unknown('依情況不同，請看條款原文');
    if (text.contains('附表倍數')) return const FormulaAmount.unknown('依手術或處置項目的倍數，請查條款附表');
    if (text.contains('計劃')) return const FormulaAmount.unknown('依投保計劃不同，請看保單');
    if (text.contains('依保單') || text.contains('依已繳') || text.contains('限額為限')) {
      return const FormulaAmount.unknown('依保單記載的金額，請看保單');
    }

    final List<String> notes = [];
    // 1. 「第2年起：保額 × 20%（第1年內：保費 × 1）」→ 用主要那段，記下條件
    final RegExpMatch? prefix = _conditionPrefixPattern.firstMatch(text);
    if (prefix != null) {
      notes.add('${prefix.group(1)}的金額');
      text = text.substring(prefix.end);
    }
    // 2. 括號裡是補充（第一年的算法、係數）：拿掉；有係數就提醒沒乘
    final RegExpMatch? bracket = RegExp(r'（(.*)）').firstMatch(text);
    if (bracket != null) {
      final String bracketText = bracket.group(1) ?? '';
      if (bracketText.contains('係數')) notes.add('未含增額或健康促進係數');
      text = text.replaceRange(bracket.start, bracket.end, '').trim();
    }
    final String? note = notes.isEmpty ? null : notes.join('，');

    // 3. 「保額 × 5%～20%」取最低
    final RegExpMatch? range = _rangePattern.firstMatch(text);
    if (range != null) {
      final int? coverage = input.coverageAmount;
      if (coverage == null) return const FormulaAmount.unknown('先在試算填保額');
      final double lowPercent = double.parse(range.group(1)!);
      return FormulaAmount(amount: (coverage * lowPercent / 100).round(), note: '依投保年數，最低的比例', isMinimum: true);
    }

    // 4. 「取較高：A／B／C」：每一段算得出來的取最大；有「保單價值」就是「至少」
    if (text.startsWith('取較高：')) {
      return _higherOf(text.substring('取較高：'.length), input, note);
    }
    return _single(text, input, note, disabilityRatio);
  }

  static FormulaAmount _higherOf(String text, BenefitTrialInput input, String? note) {
    int? best;
    bool hasUnknownTerm = false;
    for (final String term in text.split('／')) {
      final FormulaAmount termAmount = _single(term.trim(), input, null, null);
      final int? amount = termAmount.amount;
      if (amount == null) {
        hasUnknownTerm = true;
        continue;
      }
      if (best == null || amount > best) best = amount;
    }
    if (best == null) return const FormulaAmount.unknown('先在試算填保額或年繳保費');
    return FormulaAmount(amount: best, note: note, isMinimum: hasUnknownTerm);
  }

  static FormulaAmount _single(String text, BenefitTrialInput input, String? note, double? disabilityRatio) {
    // 「保額 × 附表比例」：失能情境才算得出來
    if (text.contains('附表比例')) {
      final int? coverage = input.coverageAmount;
      if (disabilityRatio == null) return const FormulaAmount.unknown('依失能等級比例，請在意外情境選等級');
      if (coverage == null) return const FormulaAmount.unknown('先在試算填保額');
      double multiplier = 1;
      final RegExpMatch? extra = RegExp(r'保額 × ([\d.]+)(%?) × 附表比例').firstMatch(text);
      if (extra != null) {
        multiplier = double.parse(extra.group(1)!);
        if (extra.group(2) == '%') multiplier = multiplier / 100;
      }
      return FormulaAmount(amount: (coverage * multiplier * disabilityRatio).round(), note: note);
    }

    final RegExpMatch? baseTimes = _baseTimesPattern.firstMatch(text);
    if (baseTimes != null) {
      final String base = baseTimes.group(1)!;
      final int? baseAmount = _baseAmountOf(base, input);
      if (baseAmount == null) return FormulaAmount.unknown('先在試算填$base');
      double amount = baseAmount * double.parse(baseTimes.group(2)!);
      if (baseTimes.group(3) == '%') amount = amount / 100;
      final String? secondMultiplier = baseTimes.group(5);
      if (secondMultiplier != null) {
        amount = amount * double.parse(secondMultiplier);
        if ((baseTimes.group(4) ?? '').contains('%')) amount = amount / 100;
      }
      return FormulaAmount(amount: amount.round(), isPerDay: baseTimes.group(6) != null, note: note);
    }
    // 「日額 × 天數」（沒有倍數）
    if (text == '日額 × 天數') {
      final int? daily = input.dailyAmount;
      if (daily == null) return const FormulaAmount.unknown('先在試算填日額');
      return FormulaAmount(amount: daily, isPerDay: true, note: note);
    }

    final RegExpMatch? perUnit = _perUnitPattern.firstMatch(text);
    if (perUnit != null) {
      final int? units = input.units;
      if (units == null) return const FormulaAmount.unknown('先在試算填投保單位');
      final int perUnitAmount = int.parse(perUnit.group(2)!.replaceAll(',', ''));
      final bool isPerDay = perUnit.group(1) == '每日' || perUnit.group(3) != null;
      if (perUnit.group(1) == '每年') {
        return FormulaAmount(amount: perUnitAmount * units, note: '每年給付一次，這裡算一年');
      }
      return FormulaAmount(amount: perUnitAmount * units, isPerDay: isPerDay, note: note);
    }

    final RegExpMatch? fixed = _fixedPattern.firstMatch(text);
    if (fixed != null) {
      return FormulaAmount(amount: int.parse(fixed.group(1)!.replaceAll(',', '')), note: note);
    }
    final RegExpMatch? tenThousands = _tenThousandsPattern.firstMatch(text);
    if (tenThousands != null) {
      return FormulaAmount(amount: (double.parse(tenThousands.group(1)!) * 10000).round(), note: note);
    }
    if (text.contains('保單價值')) return const FormulaAmount.unknown('依保單價值準備金，請看保單');
    return const FormulaAmount.unknown('這種算法還不會自動算，請看條款原文');
  }

  static int? _baseAmountOf(String base, BenefitTrialInput input) {
    if (base == '保額') return input.coverageAmount;
    if (base == '日額') return input.dailyAmount;
    if (base == '保費') return input.annualPremium;
    return null;
  }
}
