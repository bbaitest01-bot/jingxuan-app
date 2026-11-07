import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_policy_service.dart';
import 'customer_service.dart';

/// 選人視窗的一位客戶
class PartyCustomer {
  final String id;
  final String name;
  final String phone;

  const PartyCustomer({required this.id, required this.name, required this.phone});
}

/// 保單的要保人、被保險人、受益人（2026-11-07 主管回饋；模型圖沛沛確認）
///
/// 比喻：保單像一張禮物卡。要保人＝出錢買卡的人，被保險人＝卡保護的對象，受益人＝出事時拿到錢的人。
/// 例：王美華（要保人）幫兒子陳小寶（被保險人）買保險 → 這張保單的保障算在陳小寶的健檢裡。
/// 只記「是哪一位客戶」，不存姓名、身分證字號；資料庫會擋住選到別的業務員的客戶。
class PolicyPartyService {
  static final PolicyPartyService _instance = PolicyPartyService._internal();
  factory PolicyPartyService() => _instance;
  PolicyPartyService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 健檢要算的保單：自己名下且保的是自己的，加上別人名下但保的是這位客戶的
  static List<CustomerEnrolledPolicy> policiesCoveringCustomer(
    String customerId,
    List<CustomerEnrolledPolicy> ownPolicies,
    List<CustomerEnrolledPolicy> policiesFromOthers,
  ) {
    final List<CustomerEnrolledPolicy> covering = [];
    for (final CustomerEnrolledPolicy policy in ownPolicies) {
      if (policy.effectiveInsuredId == customerId) covering.add(policy);
    }
    covering.addAll(policiesFromOthers);
    return covering;
  }

  /// 掛在別的客戶名下、但被保險人是這位客戶的保單（例：媽媽幫他買的）
  Future<List<CustomerEnrolledPolicy>> fetchPoliciesFromOthers(String customerId) async {
    if (customerId.isEmpty) return [];
    try {
      final List<dynamic> rows = await _supabase
          .from('customer_policies')
          .select()
          .eq('insured_customer_id', customerId)
          .neq('customer_id', customerId);
      final List<CustomerEnrolledPolicy> policies = [];
      for (final dynamic row in rows) {
        policies.add(CustomerEnrolledPolicy.fromJson(row as Map<String, dynamic>));
      }
      return policies;
    } catch (error) {
      if (kDebugMode) debugPrint('讀取保障這位客戶的保單失敗: $error');
      return [];
    }
  }

  /// 卡片要顯示的名字：保單掛的客戶＋三個人；{客戶 id: 姓名}
  Future<Map<String, String>> fetchNamesFor(List<CustomerEnrolledPolicy> policies) async {
    final Set<String> ids = {};
    for (final CustomerEnrolledPolicy policy in policies) {
      ids.add(policy.customerId);
      final String? policyholderId = policy.policyholderCustomerId;
      final String? insuredId = policy.insuredCustomerId;
      final String? beneficiaryId = policy.beneficiaryCustomerId;
      if (policyholderId != null) ids.add(policyholderId);
      if (insuredId != null) ids.add(insuredId);
      if (beneficiaryId != null) ids.add(beneficiaryId);
    }
    final Map<String, String> names = {};
    ids.removeWhere((String id) => id.isEmpty);
    if (ids.isEmpty) return names;
    try {
      final List<dynamic> rows = await _supabase.from('customers').select('id, name').inFilter('id', ids.toList());
      for (final dynamic row in rows) {
        final Map<String, dynamic> data = row as Map<String, dynamic>;
        names[data['id'].toString()] = data['name']?.toString() ?? '';
      }
    } catch (error) {
      if (kDebugMode) debugPrint('讀取客戶姓名失敗: $error');
    }
    return names;
  }

  /// 選人視窗用：自己名下、不在垃圾桶的客戶（依姓名排序）
  Future<List<PartyCustomer>> fetchMyCustomers() async {
    final List<Map<String, dynamic>> rows = await CustomerPolicyService().fetchMyCustomersForEnroll();
    final List<PartyCustomer> customers = [];
    for (final Map<String, dynamic> row in rows) {
      customers.add(PartyCustomer(
        id: row['id'].toString(),
        name: row['name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
      ));
    }
    return customers;
  }

  /// 名單上沒有的人：只用名字建一筆簡易客戶，之後再到客戶頁補資料；回傳新客戶
  Future<PartyCustomer> createQuickCustomer(String name) async {
    final String id = await CustomerService.instance.createCustomerWithName(name.trim());
    return PartyCustomer(id: id, name: name.trim(), phone: '');
  }

  /// 存三個人（整張保單一起）；選的是保單掛的客戶自己就存空值（＝自己）。失敗丟出例外讓畫面提示
  Future<void> saveParties({
    required String customerId,
    required List<CustomerEnrolledPolicy> items,
    required String? policyholderId,
    required String? insuredId,
    required String? beneficiaryId,
    required String? beneficiaryText,
  }) async {
    String? policyholderToSave = policyholderId;
    if (policyholderToSave == customerId) policyholderToSave = null;
    String? insuredToSave = insuredId;
    if (insuredToSave == customerId) insuredToSave = null;
    String? textToSave = beneficiaryText?.trim();
    if (textToSave != null && textToSave.isEmpty) textToSave = null;

    final List<String> ids = [];
    for (final CustomerEnrolledPolicy item in items) {
      ids.add(item.id);
    }
    await _supabase.from('customer_policies').update({
      'policyholder_customer_id': policyholderToSave,
      'insured_customer_id': insuredToSave,
      'beneficiary_customer_id': beneficiaryId,
      'beneficiary_text': textToSave,
    }).inFilter('id', ids);
    CustomerPolicyService().clearCachedPolicies(customerId);
  }
}
