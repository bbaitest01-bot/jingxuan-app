import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_policy_service.dart';

/// 繳別：多久繳一次保費（2026-11-07 主管回饋：保費是業務員最在意的欄位）
class PaymentFrequency {
  static const String annual = 'annual';
  static const String semiannual = 'semiannual';
  static const String quarterly = 'quarterly';
  static const String monthly = 'monthly';
  static const String single = 'single';

  /// 選單順序就是這個順序
  static const Map<String, String> labels = {
    annual: '年繳',
    semiannual: '半年繳',
    quarterly: '季繳',
    monthly: '月繳',
    single: '躉繳',
  };

  /// 一年繳幾次；躉繳（一次繳清）不算一年保費，回傳 0
  static const Map<String, int> paymentsPerYear = {
    annual: 1,
    semiannual: 2,
    quarterly: 4,
    monthly: 12,
    single: 0,
  };

  static String label(String? frequency) => labels[frequency] ?? '';
}

/// 一位客戶一年要繳的保費：依幣別分開加總（台幣、美元不能直接相加）
class AnnualPremiumSummary {
  // {幣別代碼: 一年保費}；台幣的代碼是 TWD
  final Map<String, int> totalByCurrency;
  // 還在繳費、有保費，但沒填繳別的保單張數（沒算進總額）
  final int missingFrequencyGroupCount;
  // 有沒有「有效」（還在繳費）的保單；全部都是減額繳清、停效…時，一年總保費寫「不用繳」
  final bool hasPayingPolicy;

  const AnnualPremiumSummary({
    required this.totalByCurrency,
    required this.missingFrequencyGroupCount,
    required this.hasPayingPolicy,
  });

  bool get isEmpty => totalByCurrency.isEmpty;
}

/// 保單資料（保費、繳別、生效日）與狀態細分的計算和存檔
class PolicyDetailService {
  static final PolicyDetailService _instance = PolicyDetailService._internal();
  factory PolicyDetailService() => _instance;
  PolicyDetailService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 保額寫法：整萬寫「100 萬」「12.5 萬」，其他寫「35,000」
  static String formatAmount(int amount) {
    if (amount >= 10000 && amount % 1000 == 0) {
      String tenThousands = (amount / 10000).toStringAsFixed(1);
      if (tenThousands.endsWith('.0')) tenThousands = tenThousands.substring(0, tenThousands.length - 2);
      return '$tenThousands 萬';
    }
    return NumberFormat('#,###').format(amount);
  }

  /// 保費寫法：台幣「1,500 元」，外幣「USD 4,215」
  static String formatPremium(int amount, String currency) {
    final String number = NumberFormat('#,###').format(amount);
    if (currency == 'TWD') return '$number 元';
    return '$currency $number';
  }

  /// 一年總保費的文字：「48,600 元」「48,600 元＋USD 4,215」；沒有回傳空字串
  static String formatAnnualTotal(AnnualPremiumSummary summary) {
    final List<String> parts = [];
    final int? taiwanDollarTotal = summary.totalByCurrency['TWD'];
    if (taiwanDollarTotal != null) parts.add(formatPremium(taiwanDollarTotal, 'TWD'));
    summary.totalByCurrency.forEach((String currency, int total) {
      if (currency != 'TWD') parts.add(formatPremium(total, currency));
    });
    return parts.join('＋');
  }

  /// 一項的一年保費＝每期保費 × 一年繳幾次；沒填保費、沒填繳別、躉繳、不用再繳的回傳 null
  static int? annualPremiumOf(CustomerEnrolledPolicy policy) {
    final int? premium = policy.premium;
    final int paymentsPerYear = PaymentFrequency.paymentsPerYear[policy.paymentFrequency] ?? 0;
    if (premium == null || paymentsPerYear == 0) return null;
    if (!PolicyStatus.isPayingPremium(policy.status)) return null;
    return premium * paymentsPerYear;
  }

  /// 幣別代碼：空值當台幣
  static String currencyOf(CustomerEnrolledPolicy policy) {
    final String currency = policy.premiumCurrency ?? '';
    if (currency.isEmpty) return 'TWD';
    return currency;
  }

  /// 加總客戶全部保單的一年保費（只算還在繳費的）
  static AnnualPremiumSummary summarize(List<CustomerEnrolledPolicy> policies) {
    final Map<String, int> totalByCurrency = {};
    final Set<String> missingFrequencyGroups = {};
    bool hasPayingPolicy = false;
    for (final CustomerEnrolledPolicy policy in policies) {
      if (PolicyStatus.isPayingPremium(policy.status)) hasPayingPolicy = true;
      final int? annualPremium = annualPremiumOf(policy);
      if (annualPremium != null) {
        final String currency = currencyOf(policy);
        totalByCurrency[currency] = (totalByCurrency[currency] ?? 0) + annualPremium;
        continue;
      }
      // 有保費、還在繳，只差繳別 → 提醒業務員去補
      final bool isPaying = PolicyStatus.isPayingPremium(policy.status);
      if (isPaying && policy.premium != null && policy.paymentFrequency == null) {
        missingFrequencyGroups.add(policy.policyGroupId ?? policy.id);
      }
    }
    return AnnualPremiumSummary(
      totalByCurrency: totalByCurrency,
      missingFrequencyGroupCount: missingFrequencyGroups.length,
      hasPayingPolicy: hasPayingPolicy,
    );
  }

  /// 存「保單資料」：整張一起的生效日、繳別，加上每一項的每期保費；失敗丟出例外讓畫面提示
  Future<void> savePremiumDetails({
    required String customerId,
    required List<CustomerEnrolledPolicy> items,
    required DateTime? effectiveDate,
    required String? paymentFrequency,
    required Map<String, int?> premiumByPolicyId,
  }) async {
    String? effectiveDateText;
    if (effectiveDate != null) {
      effectiveDateText = effectiveDate.toIso8601String().substring(0, 10);
    }
    // 每一項保費不同，所以一項一項寫；生效日、繳別每項都寫一樣的值
    for (final CustomerEnrolledPolicy item in items) {
      await _supabase.from('customer_policies').update({
        'effective_date': effectiveDateText,
        'payment_frequency': paymentFrequency,
        'premium': premiumByPolicyId[item.id],
      }).eq('id', item.id);
    }
    CustomerPolicyService().clearCachedPolicies(customerId);
  }

  /// 存「保單狀態」：這幾項一起改成同一個狀態與貸款加註；
  /// 減額繳清時把新保額寫在 reducedItemId 那一項（整張改時是主約），其他項清空
  Future<void> saveStatusDetails({
    required String customerId,
    required List<CustomerEnrolledPolicy> items,
    required String status,
    required bool hasPolicyLoan,
    required String? reducedItemId,
    required int? reducedCoverageAmount,
  }) async {
    for (final CustomerEnrolledPolicy item in items) {
      int? reducedAmount;
      if (status == PolicyStatus.reducedPaidUp && item.id == reducedItemId) {
        reducedAmount = reducedCoverageAmount;
      }
      await _supabase.from('customer_policies').update({
        'status': status,
        'has_policy_loan': hasPolicyLoan,
        'reduced_coverage_amount': reducedAmount,
      }).eq('id', item.id);
    }
    CustomerPolicyService().clearCachedPolicies(customerId);
  }
}
