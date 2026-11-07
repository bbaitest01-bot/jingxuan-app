// 情境試算的資料模型（2026-11-07 沛沛確認：比較頁最上面填情境，每款商品算「這個情境大約可以拿多少」）
//
// 比喻：比較頁原本像「菜單」，只看得到每一項最多賠多少；情境試算是「點好一桌菜」，算總共給多少。
// 保險給錢只有三種方式：報帳型（實支實付，花多少報多少、有上限）、按天給（日額 × 天數）、
// 一次給（事情發生就給保額 × 比例）。每個情境會用到其中幾種。

/// 六種情境（每一種保險都在等不同的「事情」發生）
class ClaimScenarioType {
  static const String hospital = 'hospital';
  static const String death = 'death';
  static const String cancer = 'cancer';
  static const String criticalIllness = 'critical_illness';
  static const String longTermCare = 'long_term_care';
  static const String accident = 'accident';

  /// 按鈕順序就是這個順序
  static const Map<String, String> labels = {
    hospital: '住院',
    death: '身故',
    cancer: '確診癌症',
    criticalIllness: '重大疾病',
    longTermCare: '長期照顧',
    accident: '意外受傷',
  };

  static String label(String type) => labels[type] ?? '';
}

/// 業務員在情境區填的數字（全部都有預設值，打開就看得到結果）
class ClaimScenarioInput {
  final String type;
  // 住院：天數、每天病房差額（自付）、自費醫療費、手術自費（0＝沒開刀）
  final int hospitalDays;
  final int roomDifferencePerDay;
  final int medicalExpense;
  final int surgeryExpense;
  // 身故：是不是意外
  final bool isAccidentalDeath;
  // 癌症：是不是重度（false＝初期／輕度）
  final bool isSevereCancer;
  // 重大疾病：是不是重度（false＝輕度）
  final bool isSevereCriticalIllness;
  // 長期照顧：要照顧幾個月
  final int careMonths;
  // 意外：失能等級（0＝沒有失能，1～11 級，1 級最嚴重）
  final int disabilityLevel;

  const ClaimScenarioInput({
    this.type = ClaimScenarioType.hospital,
    this.hospitalDays = 5,
    this.roomDifferencePerDay = 3000,
    this.medicalExpense = 150000,
    this.surgeryExpense = 100000,
    this.isAccidentalDeath = false,
    this.isSevereCancer = true,
    this.isSevereCriticalIllness = true,
    this.careMonths = 12,
    this.disabilityLevel = 0,
  });

  ClaimScenarioInput copyWith({
    String? type,
    int? hospitalDays,
    int? roomDifferencePerDay,
    int? medicalExpense,
    int? surgeryExpense,
    bool? isAccidentalDeath,
    bool? isSevereCancer,
    bool? isSevereCriticalIllness,
    int? careMonths,
    int? disabilityLevel,
  }) {
    return ClaimScenarioInput(
      type: type ?? this.type,
      hospitalDays: hospitalDays ?? this.hospitalDays,
      roomDifferencePerDay: roomDifferencePerDay ?? this.roomDifferencePerDay,
      medicalExpense: medicalExpense ?? this.medicalExpense,
      surgeryExpense: surgeryExpense ?? this.surgeryExpense,
      isAccidentalDeath: isAccidentalDeath ?? this.isAccidentalDeath,
      isSevereCancer: isSevereCancer ?? this.isSevereCancer,
      isSevereCriticalIllness: isSevereCriticalIllness ?? this.isSevereCriticalIllness,
      careMonths: careMonths ?? this.careMonths,
      disabilityLevel: disabilityLevel ?? this.disabilityLevel,
    );
  }

  bool get hasSurgery => surgeryExpense > 0;

  /// 住院自己要付的錢合計：病房差額 × 天數＋醫療費＋手術費
  int get hospitalOutOfPocket => roomDifferencePerDay * hospitalDays + medicalExpense + surgeryExpense;
}

/// 明細的一行：「病房 2,000 × 5 天」1 萬
class ClaimScenarioLine {
  final String label;
  final int amount;
  // 補充說明：「第 2 年起」「未含增額係數」…；沒有是 null
  final String? note;

  const ClaimScenarioLine(this.label, this.amount, {this.note});
}

/// 一款商品在這個情境的結果
class ClaimScenarioResult {
  final List<ClaimScenarioLine> lines;
  // 算不出來、沒加進去的項目（例：「住院手術醫療保險金：依手術項目倍數，請查條款附表」）
  final List<String> notCounted;
  // 有些項目是「至少」（取較高、依投保年數）→ 金額後面加「起」
  final bool isMinimum;
  // 整款都沒有結果時的原因（例：「這款在這個情境不給付」）；有結果時是 null
  final String? emptyReason;
  // 實支實付（看收據）才可以選「買幾張」
  final bool canBuyMultipleCopies;

  const ClaimScenarioResult({
    this.lines = const [],
    this.notCounted = const [],
    this.isMinimum = false,
    this.emptyReason,
    this.canBuyMultipleCopies = false,
  });

  int get total {
    int sum = 0;
    for (final ClaimScenarioLine line in lines) {
      sum += line.amount;
    }
    return sum;
  }

  /// 有算出金額，或有「算不出來」要提醒
  bool get hasContent => lines.isNotEmpty || notCounted.isNotEmpty;

  /// 買幾張：每一行都乘張數（副本理賠，每張各自照上限賠）
  ClaimScenarioResult timesCopies(int copies) {
    if (copies <= 1) return this;
    final List<ClaimScenarioLine> multipliedLines = [];
    for (final ClaimScenarioLine line in lines) {
      multipliedLines.add(ClaimScenarioLine('${line.label} × $copies 張', line.amount * copies, note: line.note));
    }
    return ClaimScenarioResult(
      lines: multipliedLines,
      notCounted: notCounted,
      isMinimum: isMinimum,
      emptyReason: emptyReason,
      canBuyMultipleCopies: canBuyMultipleCopies,
    );
  }
}
