import 'claim_scenario.dart';

/// 一個給付項目在這個情境要怎麼用
class ScenarioItemUse {
  // 這個情境會不會給這一項
  final bool isIncluded;
  // 會給，但算不出來（要另外確認）的原因；例：「要住加護病房才給」→ 列在「沒加進去」
  final String? conditionNote;
  // 算得出來，但有條件要提醒；例：「限條款列的特定疾病」→ 照算，明細旁邊寫提醒
  final String? lineNote;
  // 按天或按月給的項目：乘幾天／幾個月；一次給的是 1
  final int multiplier;
  // 「天」或「個月」（明細顯示「× 5 天」用）；一次給的是空字串
  final String multiplierUnit;
  // 意外失能：這一級的比例（1 級 100%…11 級 5%）；其他情境是 null
  final double? disabilityRatio;

  const ScenarioItemUse({
    this.isIncluded = false,
    this.conditionNote,
    this.lineNote,
    this.multiplier = 1,
    this.multiplierUnit = '',
    this.disabilityRatio,
  });

  static const ScenarioItemUse notIncluded = ScenarioItemUse();
}

/// 依給付項目名稱判斷它屬於哪個情境（1,725 個項目用規則分，不逐筆人工標）
///
/// 規則的想法（白話）：
/// - 住院：名稱有「住院」「出院療養」，但不是癌症、意外的住院
/// - 身故：名稱有「身故」「喪葬」；疾病身故時不算意外、傷害、交通的身故
/// - 癌症：名稱有「癌」；分初期（初期、輕度、原位）與重度
/// - 重大疾病：名稱有「重大疾病」「重大傷病」「特定傷病」；分輕度、重度
/// - 長期照顧：名稱有「長期照顧」「長照」「照護」；名稱有「分期」「每月」的按月給
/// - 意外：名稱有「失能」（依等級比例）、意外或傷害的住院
class ScenarioItemMatcher {
  /// 失能等級給付比例（保險業通用的失能程度表：1 級 100%，每降一級少 10%，11 級 5%）
  static const Map<int, double> disabilityRatios = {
    1: 1.0, 2: 0.9, 3: 0.8, 4: 0.7, 5: 0.6, 6: 0.5, 7: 0.4, 8: 0.3, 9: 0.2, 10: 0.1, 11: 0.05,
  };

  static bool _hasAny(String text, List<String> keywords) {
    for (final String keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  static ScenarioItemUse useOf(String itemName, String? formula, ClaimScenarioInput input) {
    final String name = itemName;
    switch (input.type) {
      case ClaimScenarioType.hospital:
        return _hospital(name, formula ?? '', input);
      case ClaimScenarioType.death:
        return _death(name, input);
      case ClaimScenarioType.cancer:
        return _cancer(name, formula ?? '', input);
      case ClaimScenarioType.criticalIllness:
        return _criticalIllness(name, input);
      case ClaimScenarioType.longTermCare:
        return _longTermCare(name, formula ?? '', input);
      case ClaimScenarioType.accident:
        return _accident(name, formula ?? '', input);
    }
    return ScenarioItemUse.notIncluded;
  }

  static const List<String> _accidentWords = ['意外', '傷害', '交通', '航空', '燒燙傷', '骨折'];

  static ScenarioItemUse _hospital(String name, String formula, ClaimScenarioInput input) {
    if (name.contains('癌')) return ScenarioItemUse.notIncluded;
    // 加護病房要先判斷：名稱常寫「加護病房、燒燙傷病房」，不能被當成意外排除
    if (_hasAny(name, ['加護病房', '燒燙傷病房'])) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '要住加護病房才給，天數另計');
    }
    if (_hasAny(name, _accidentWords)) return ScenarioItemUse.notIncluded;
    if (name.contains('手術')) {
      if (!input.hasSurgery) return ScenarioItemUse.notIncluded;
      if (name.contains('門診')) return ScenarioItemUse.notIncluded;
      // 器官移植、骨髓移植是特定大手術，不是一般開刀（2026-11-07 抽查）
      if (name.contains('移植')) {
        return const ScenarioItemUse(isIncluded: true, conditionNote: '限器官或骨髓移植手術');
      }
      return const ScenarioItemUse(isIncluded: true);
    }
    if (name.contains('老年')) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '限一定年齡以上住院才給');
    }
    if (_hasAny(name, ['住院', '療養'])) {
      if (name.contains('門診')) return ScenarioItemUse.notIncluded;
      return _perDayIfNeeded(formula, input.hospitalDays);
    }
    return ScenarioItemUse.notIncluded;
  }

  static ScenarioItemUse _death(String name, ClaimScenarioInput input) {
    if (!_hasAny(name, ['身故', '喪葬'])) return ScenarioItemUse.notIncluded;
    final bool isAccidentItem = _hasAny(name, _accidentWords);
    if (isAccidentItem && !input.isAccidentalDeath) return ScenarioItemUse.notIncluded;
    if (_hasAny(name, _specialAccidentWords)) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: _specialAccidentNote);
    }
    return const ScenarioItemUse(isIncluded: true);
  }

  // 只有特定意外（搭飛機、大眾運輸、火災…）才另外加給的項目：不算進一般意外（2026-11-07 抽查）
  static const List<String> _specialAccidentWords = ['航空', '交通', '大眾運輸', '火災', '燒燙傷', '電梯', '颱風', '地震'];
  static const String _specialAccidentNote = '限特定意外（交通、航空、火災…）時另給';

  static ScenarioItemUse _cancer(String name, String formula, ClaimScenarioInput input) {
    if (!name.contains('癌')) return ScenarioItemUse.notIncluded;
    final bool isEarlyItem = _hasAny(name, ['初期', '輕度', '原位']);
    final bool isSevereItem = name.contains('重度');
    // 「初期或輕度」只在初期給；「重度」只在重度給；兩個都沒寫的兩邊都給
    if (isEarlyItem && !isSevereItem && input.isSevereCancer) return ScenarioItemUse.notIncluded;
    if (isSevereItem && !isEarlyItem && !input.isSevereCancer) return ScenarioItemUse.notIncluded;
    // 治療項目先判斷（「特定粒子放射治療」是治療方式，不是特定癌症）
    if (_hasAny(name, ['門診', '化學', '放射', '標靶', '免疫', '安寧', '義乳', '重建', '移植', '追蹤'])) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '看治療方式與次數，請看條款');
    }
    // 特定癌症：只有條款列的那幾種癌症才另外給，一般確診不算（2026-11-07 抽查：會把初期算太多）
    if (name.contains('特定')) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '限條款列的特定癌症，符合時另給');
    }
    if (name.contains('手術')) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '有開刀才給');
    }
    if (_hasAny(name, ['住院', '療養'])) return _perDayIfNeeded(formula, input.hospitalDays);
    return const ScenarioItemUse(isIncluded: true);
  }

  static ScenarioItemUse _criticalIllness(String name, ClaimScenarioInput input) {
    if (!_hasAny(name, ['重大疾病', '重大傷病', '特定傷病', '重症'])) return ScenarioItemUse.notIncluded;
    if (name.contains('癌')) return ScenarioItemUse.notIncluded;
    // 名稱有「輕度」只在輕度給；其他（「重度」或沒寫）只在重度給
    // （2026-11-07 抽查：「重大疾病保險金」沒寫輕重，就是重度，不能在輕度情境也算）
    final bool isMildItem = name.contains('輕度');
    if (isMildItem && input.isSevereCriticalIllness) return ScenarioItemUse.notIncluded;
    if (!isMildItem && !input.isSevereCriticalIllness) return ScenarioItemUse.notIncluded;
    if (name.contains('特定')) {
      return const ScenarioItemUse(isIncluded: true, lineNote: '限條款列的特定疾病');
    }
    return const ScenarioItemUse(isIncluded: true);
  }

  static ScenarioItemUse _longTermCare(String name, String formula, ClaimScenarioInput input) {
    if (!_hasAny(name, ['長期照顧', '長照', '照護', '失能扶助'])) return ScenarioItemUse.notIncluded;
    if (_hasAny(name, ['分期', '每月', '扶助', '關懷'])) {
      // 「保額 × 12」是一年給一次（月額 × 12），照顧幾年就給幾次；「保額 × 1」才是每月給
      // （2026-11-07 抽查：原本當每月再乘 12 個月，多算 12 倍）
      if (formula.contains('× 12')) {
        final int years = (input.careMonths + 11) ~/ 12;
        return ScenarioItemUse(isIncluded: true, multiplier: years, multiplierUnit: '年');
      }
      return ScenarioItemUse(isIncluded: true, multiplier: input.careMonths, multiplierUnit: '個月');
    }
    return const ScenarioItemUse(isIncluded: true);
  }

  static ScenarioItemUse _accident(String name, String formula, ClaimScenarioInput input) {
    if (name.contains('失能')) {
      final double? ratio = disabilityRatios[input.disabilityLevel];
      if (ratio == null) return ScenarioItemUse.notIncluded;
      // 「完全失能」「第一級失能」只有 1 級才給
      if (_hasAny(name, ['完全失能', '第一級']) && input.disabilityLevel != 1) return ScenarioItemUse.notIncluded;
      if (_hasAny(name, _specialAccidentWords)) {
        return const ScenarioItemUse(isIncluded: true, conditionNote: _specialAccidentNote);
      }
      if (name.contains('扶助')) {
        return const ScenarioItemUse(isIncluded: true, conditionNote: '失能扶助金依等級按年或按月給，請看條款');
      }
      return ScenarioItemUse(isIncluded: true, disabilityRatio: ratio);
    }
    if (!_hasAny(name, _accidentWords)) return ScenarioItemUse.notIncluded;
    if (name.contains('身故')) return ScenarioItemUse.notIncluded;
    // 「傷害醫療日額」「意外住院」：按住院天數給
    if (name.contains('住院') || formula.contains('天數')) {
      if (_hasAny(name, ['加護病房', '燒燙傷'])) {
        return const ScenarioItemUse(isIncluded: true, conditionNote: '要住加護病房或燒燙傷病房才給');
      }
      return _perDayIfNeeded(formula, input.hospitalDays);
    }
    if (_hasAny(name, ['骨折', '燒燙傷', '手術', '醫療', '處置'])) {
      return const ScenarioItemUse(isIncluded: true, conditionNote: '看受傷部位或醫療費用，請看條款');
    }
    return ScenarioItemUse.notIncluded;
  }

  /// 算法有「天數」「每日」才乘天數，否則是一次給
  static ScenarioItemUse _perDayIfNeeded(String formula, int days) {
    if (formula.contains('天數') || formula.contains('每日')) {
      return ScenarioItemUse(isIncluded: true, multiplier: days, multiplierUnit: '天');
    }
    return const ScenarioItemUse(isIncluded: true);
  }
}
