import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'insurance_product_service.dart';

/// 客戶已投保保單項目
class CustomerEnrolledPolicy {
  final String id;
  final String customerId;
  final String policyClauseId;
  final String productName;
  final String companyName;
  final String category;
  // 限額文字；空字串＝沒有資料（真實商品目前都沒有，第二層比價資料做好才會有）
  final String roomLimit;
  final String surgeryLimit;
  final String miscLimit;
  final int? roomDailyValue;
  final int? surgeryMaxValue;
  final int? miscMaxValue;
  final String rawPdfUrl;
  final DateTime enrolledAt;
  // 保單狀態（六種，見 PolicyStatus；2026-11-07 主管回饋細分）
  final String status;
  // 有保單貸款（不是狀態，是有效保單上的加註）
  final bool hasPolicyLoan;
  // 減額繳清後的新保額（元）；只有減額繳清時使用
  final int? reducedCoverageAmount;
  // 繳別：annual／semiannual／quarterly／monthly／single（見 PaymentFrequency）；空值＝還沒填
  final String? paymentFrequency;
  // 保單的三個人（2026-11-07 主管回饋）：只記是哪一位客戶；空值＝就是這張保單掛的客戶自己
  final String? policyholderCustomerId;
  final String? insuredCustomerId;
  final String? beneficiaryCustomerId;
  // 受益人不是客戶時直接寫（例：法定繼承人）
  final String? beneficiaryText;
  // 掃描保單帶進來的欄位（4-J）；手動加入的保單這些多半是空的
  final String? policyGroupId;
  final String? policyNumber;
  final String? coverageRole;
  final String? planOrAmount;
  final DateTime? effectiveDate;
  final int? premium;
  final String? premiumCurrency;
  final String source;
  // 保單健檢（4-L）：業務員改過的保障類別、保額、實支計畫
  final String? coverageCategory;
  final int? coverageAmount;
  final String? benefitPlanId;

  CustomerEnrolledPolicy({
    required this.id,
    required this.customerId,
    required this.policyClauseId,
    required this.productName,
    required this.companyName,
    required this.category,
    required this.roomLimit,
    required this.surgeryLimit,
    required this.miscLimit,
    required this.roomDailyValue,
    required this.surgeryMaxValue,
    required this.miscMaxValue,
    required this.rawPdfUrl,
    required this.enrolledAt,
    this.status = PolicyStatus.active,
    this.hasPolicyLoan = false,
    this.reducedCoverageAmount,
    this.paymentFrequency,
    this.policyholderCustomerId,
    this.insuredCustomerId,
    this.beneficiaryCustomerId,
    this.beneficiaryText,
    this.policyGroupId,
    this.policyNumber,
    this.coverageRole,
    this.planOrAmount,
    this.effectiveDate,
    this.premium,
    this.premiumCurrency,
    this.source = 'manual',
    this.coverageCategory,
    this.coverageAmount,
    this.benefitPlanId,
  });

  /// 有保障（有效、減額繳清、展期定期）；放在「有效保單」區、算進健檢
  bool get isActive => PolicyStatus.hasCoverage(status);

  /// 被保險人是哪位客戶（沒填就是保單掛的客戶自己）；健檢算在這個人身上
  String get effectiveInsuredId => insuredCustomerId ?? customerId;

  /// 要保人是哪位客戶（沒填就是保單掛的客戶自己）
  String get effectivePolicyholderId => policyholderCustomerId ?? customerId;

  /// 有沒有填過三個人的任何一個（沒填過的卡片不顯示「要保人…」那一行）
  bool get hasPartyDetails {
    final String text = beneficiaryText ?? '';
    return policyholderCustomerId != null || insuredCustomerId != null || beneficiaryCustomerId != null || text.isNotEmpty;
  }

  /// 健檢用的保額：減額繳清且有填新保額就用新保額，否則用原本的保額
  int? get coverageAmountForCheck {
    final int? reducedAmount = reducedCoverageAmount;
    if (status == PolicyStatus.reducedPaidUp && reducedAmount != null) {
      return reducedAmount;
    }
    return coverageAmount;
  }

  /// 有對到商品目錄（policy_clause_id 有值）；掃描時目錄找不到的商品這裡是 false
  bool get isInCatalog => policyClauseId.isNotEmpty;

  /// 主約／附約的中文；沒有資料回傳空字串
  String get coverageRoleLabel {
    if (coverageRole == 'main') {
      return '主約';
    }
    if (coverageRole == 'rider') {
      return '附約';
    }
    return '';
  }

  /// 三種限額數字都有，才能算進保障總額
  bool get hasLimitData {
    return roomDailyValue != null && surgeryMaxValue != null && miscMaxValue != null;
  }

  factory CustomerEnrolledPolicy.fromJson(Map<String, dynamic> json) {
    final benefits = json['benefits_json'] as Map<String, dynamic>?;
    return CustomerEnrolledPolicy(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      policyClauseId: json['policy_clause_id']?.toString() ?? '',
      productName: json['product_name'] ?? '保險商品',
      companyName: json['company_name'] ?? '保險公司',
      category: json['category'] ?? '醫療保險',
      // 沒有資料就留空，不再自動補上假的限額
      roomLimit: json['room_limit'] ?? '',
      surgeryLimit: json['surgery_limit'] ?? '',
      miscLimit: json['misc_limit'] ?? '',
      roomDailyValue: (benefits?['room_daily'] as num?)?.toInt(),
      surgeryMaxValue: (benefits?['surgery_max'] as num?)?.toInt(),
      miscMaxValue: (benefits?['misc_max'] as num?)?.toInt(),
      rawPdfUrl: json['raw_pdf_url'] ?? '',
      enrolledAt: json['enrolled_at'] != null ? DateTime.parse(json['enrolled_at']) : DateTime.now(),
      status: json['status']?.toString() ?? PolicyStatus.active,
      hasPolicyLoan: json['has_policy_loan'] == true,
      reducedCoverageAmount: (json['reduced_coverage_amount'] as num?)?.toInt(),
      paymentFrequency: json['payment_frequency'] as String?,
      policyholderCustomerId: json['policyholder_customer_id'] as String?,
      insuredCustomerId: json['insured_customer_id'] as String?,
      beneficiaryCustomerId: json['beneficiary_customer_id'] as String?,
      beneficiaryText: json['beneficiary_text'] as String?,
      policyGroupId: json['policy_group_id'] as String?,
      policyNumber: json['policy_number'] as String?,
      coverageRole: json['coverage_role'] as String?,
      planOrAmount: json['plan_or_amount'] as String?,
      effectiveDate: DateTime.tryParse(json['effective_date']?.toString() ?? ''),
      premium: (json['premium'] as num?)?.toInt(),
      premiumCurrency: json['premium_currency'] as String?,
      coverageCategory: json['coverage_category'] as String?,
      coverageAmount: (json['coverage_amount'] as num?)?.toInt(),
      benefitPlanId: json['benefit_plan_id'] as String?,
      source: json['source']?.toString() ?? 'manual',
    );
  }
}

/// 客戶保單狀態（2026-11-07 依主管回饋細分；畫面一樣分「有效保單／已失效保單」兩區）
///
/// 比喻：健身房會員卡。有效＝正常用；減額繳清＝不再繳錢、卡降級；展期定期＝不再繳錢、卡變成有期限；
/// 停效＝忘了繳錢被暫停（可復效）；解約＝退卡；滿期＝會員期到了
class PolicyStatus {
  static const String active = 'active';
  static const String reducedPaidUp = 'reduced_paid_up';
  static const String extendedTerm = 'extended_term';
  static const String lapsed = 'lapsed';
  static const String surrendered = 'surrendered';
  static const String matured = 'matured';

  /// 有保障的狀態（選單第一排）
  static const List<String> withCoverage = [active, reducedPaidUp, extendedTerm];

  /// 沒有保障的狀態（選單第二排）
  static const List<String> withoutCoverage = [lapsed, surrendered, matured];

  static const Map<String, String> labels = {
    active: '有效',
    reducedPaidUp: '減額繳清',
    extendedTerm: '展期定期',
    lapsed: '停效',
    surrendered: '解約',
    matured: '滿期',
  };

  static String label(String status) => labels[status] ?? '有效';

  static bool hasCoverage(String status) => withCoverage.contains(status);

  /// 還在繳保費（只有「有效」；減額繳清、展期定期都不用再繳）
  static bool isPayingPremium(String status) => status == active;
}

class CustomerPolicyService {
  static final CustomerPolicyService _instance = CustomerPolicyService._internal();
  factory CustomerPolicyService() => _instance;
  CustomerPolicyService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // In-memory policy cache for instant offline responsiveness
  final Map<String, List<CustomerEnrolledPolicy>> _clientPoliciesCache = {};

  /// 取得某位客戶名下所有已投保的保單
  Future<List<CustomerEnrolledPolicy>> getCustomerPolicies(String customerId) async {
    if (_clientPoliciesCache.containsKey(customerId)) {
      return _clientPoliciesCache[customerId]!;
    }

    try {
      final res = await _supabase
          .from('customer_policies')
          .select()
          .eq('customer_id', customerId)
          .order('enrolled_at', ascending: false);

      final list = (res as List).map((e) => CustomerEnrolledPolicy.fromJson(e)).toList();
      _clientPoliciesCache[customerId] = list;
      return list;
    } catch (e) {
      if (kDebugMode) print('Error fetching customer policies: $e');
      _clientPoliciesCache[customerId] = [];
      return [];
    }
  }

  /// 把一款真實商品加入客戶的已投保保單
  ///
  /// 限額欄位留空（真實商品還沒有第二層比價資料）；policy_clause_id 存 insurance_products 的 id。
  /// 寫入成功才放進快取，失敗回傳 false 讓畫面提示。
  Future<bool> enrollProductForCustomer({
    required String customerId,
    required InsuranceProduct product,
    String status = PolicyStatus.active,
  }) async {
    try {
      final Map<String, dynamic> savedRow = await _supabase
          .from('customer_policies')
          .insert({
            'customer_id': customerId,
            'policy_clause_id': product.id,
            'product_name': product.productName,
            'company_name': product.companyName,
            'category': product.insuranceTypeLabel,
            // 明確寫入空值，不讓資料表的預設值（2,000 元/日 等假數字）補上
            'room_limit': null,
            'surgery_limit': null,
            'misc_limit': null,
            'benefits_json': <String, dynamic>{},
            'raw_pdf_url': product.clauseUrl,
            'status': status,
          })
          .select()
          .single();

      final CustomerEnrolledPolicy newPolicy = CustomerEnrolledPolicy.fromJson(savedRow);
      _clientPoliciesCache.putIfAbsent(customerId, () => []);
      _clientPoliciesCache[customerId]!.insert(0, newPolicy);
      return true;
    } catch (error) {
      if (kDebugMode) print('加入客戶保單失敗: $error');
      return false;
    }
  }

  /// 「＋加到客戶」視窗用：自己名下、不在垃圾桶的客戶（依姓名排序）
  Future<List<Map<String, dynamic>>> fetchMyCustomersForEnroll() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      return [];
    }
    final response = await _supabase
        .from('customers')
        .select('id, name, phone')
        .eq('profile_id', user.id)
        .isFilter('deleted_at', null)
        .order('name');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 清掉某位客戶的保單快取（掃描存入後呼叫，下次打開客戶頁會重新讀資料庫）
  void clearCachedPolicies(String customerId) {
    _clientPoliciesCache.remove(customerId);
  }

  /// 移除客戶的已購保單
  Future<bool> removePolicyForCustomer(String customerId, String policyId) async {
    if (_clientPoliciesCache.containsKey(customerId)) {
      _clientPoliciesCache[customerId]!.removeWhere((p) => p.id == policyId);
    }
    try {
      await _supabase.from('customer_policies').delete().eq('id', policyId);
      return true;
    } catch (error) {
      if (kDebugMode) print('移除保單失敗: $error');
      return false;
    }
  }

  /// 一張保單的幾項一起刪除（D21「刪除整張保單」）；回傳成功的項數
  Future<int> removePoliciesForCustomer(String customerId, List<CustomerEnrolledPolicy> items) async {
    int successCount = 0;
    for (final CustomerEnrolledPolicy item in items) {
      if (await removePolicyForCustomer(customerId, item.id)) successCount++;
    }
    return successCount;
  }
}
