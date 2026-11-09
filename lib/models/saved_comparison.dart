import '../services/benefit_trial_calculator.dart';
import '../services/scenario/claim_scenario.dart';

/// 比較清單裡的一款商品（D36）：只存業務員選的、填的，金額打開時再重新計算
class SavedComparisonItem {
  final String productId;
  // 實支實付選的計畫；存 plan_code 而不是「第幾個」，條款資料調整順序時才不會選錯
  final String? planCode;
  final int copies;
  // 保額（元）；畫面輸入的是萬元，存的是元
  final int? coverageAmount;
  final int? dailyAmount;
  final int? units;
  final int? annualPremium;

  const SavedComparisonItem({
    required this.productId,
    this.planCode,
    this.copies = 1,
    this.coverageAmount,
    this.dailyAmount,
    this.units,
    this.annualPremium,
  });

  factory SavedComparisonItem.fromJson(Map<String, dynamic> json) {
    return SavedComparisonItem(
      productId: json['product_id']?.toString() ?? '',
      planCode: json['plan_code'] as String?,
      copies: (json['copies'] as num?)?.toInt() ?? 1,
      coverageAmount: (json['coverage_amount'] as num?)?.toInt(),
      dailyAmount: (json['daily_amount'] as num?)?.toInt(),
      units: (json['units'] as num?)?.toInt(),
      annualPremium: (json['annual_premium'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'plan_code': planCode,
      'copies': copies,
      'coverage_amount': coverageAmount,
      'daily_amount': dailyAmount,
      'units': units,
      'annual_premium': annualPremium,
    };
  }

  /// 轉成比較頁用的試算數字；幣別看商品名稱，不存在這裡
  BenefitTrialInput toTrialInput(String currencyUnit) {
    return BenefitTrialInput(
      coverageAmount: coverageAmount,
      dailyAmount: dailyAmount,
      units: units,
      annualPremium: annualPremium,
      currencyUnit: currencyUnit,
    );
  }
}

/// 情境試算數字和資料庫 JSON 之間的轉換
class SavedComparisonScenario {
  static Map<String, dynamic> toJson(ClaimScenarioInput input) {
    return {
      'type': input.type,
      'hospital_days': input.hospitalDays,
      'room_difference_per_day': input.roomDifferencePerDay,
      'medical_expense': input.medicalExpense,
      'surgery_expense': input.surgeryExpense,
      'is_accidental_death': input.isAccidentalDeath,
      'is_severe_cancer': input.isSevereCancer,
      'is_severe_critical_illness': input.isSevereCriticalIllness,
      'care_months': input.careMonths,
      'disability_level': input.disabilityLevel,
    };
  }

  /// 資料裡沒有的欄位用情境試算的預設值，之後情境多加欄位時舊資料一樣打得開
  static ClaimScenarioInput fromJson(Map<String, dynamic> json) {
    const ClaimScenarioInput defaults = ClaimScenarioInput();
    return ClaimScenarioInput(
      type: json['type'] as String? ?? defaults.type,
      hospitalDays: (json['hospital_days'] as num?)?.toInt() ?? defaults.hospitalDays,
      roomDifferencePerDay: (json['room_difference_per_day'] as num?)?.toInt() ?? defaults.roomDifferencePerDay,
      medicalExpense: (json['medical_expense'] as num?)?.toInt() ?? defaults.medicalExpense,
      surgeryExpense: (json['surgery_expense'] as num?)?.toInt() ?? defaults.surgeryExpense,
      isAccidentalDeath: json['is_accidental_death'] as bool? ?? defaults.isAccidentalDeath,
      isSevereCancer: json['is_severe_cancer'] as bool? ?? defaults.isSevereCancer,
      isSevereCriticalIllness: json['is_severe_critical_illness'] as bool? ?? defaults.isSevereCriticalIllness,
      careMonths: (json['care_months'] as num?)?.toInt() ?? defaults.careMonths,
      disabilityLevel: (json['disability_level'] as num?)?.toInt() ?? defaults.disabilityLevel,
    );
  }
}

/// 存在客戶底下的一次比較（資料表 customer_saved_comparisons，全景地圖 4-R）
class SavedComparison {
  final String id;
  final String customerId;
  final String name;
  final ClaimScenarioInput scenario;
  final List<SavedComparisonItem> items;
  final DateTime updatedAt;

  const SavedComparison({
    required this.id,
    required this.customerId,
    required this.name,
    required this.scenario,
    required this.items,
    required this.updatedAt,
  });

  /// 這款商品當時存的內容；後來才加進比較的商品回傳 null
  SavedComparisonItem? itemFor(String productId) {
    for (final SavedComparisonItem item in items) {
      if (item.productId == productId) {
        return item;
      }
    }
    return null;
  }

  factory SavedComparison.fromJson(Map<String, dynamic> json) {
    final List<SavedComparisonItem> items = [];
    final List<dynamic> itemRows = json['items'] as List<dynamic>? ?? const [];
    for (final dynamic itemRow in itemRows) {
      items.add(SavedComparisonItem.fromJson(Map<String, dynamic>.from(itemRow as Map)));
    }
    final Map<String, dynamic> scenarioRow = Map<String, dynamic>.from(json['scenario'] as Map? ?? const {});
    return SavedComparison(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      scenario: SavedComparisonScenario.fromJson(scenarioRow),
      items: items,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
