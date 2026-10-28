import 'customer_policy_service.dart';

/// 一張保單：同一次掃描（同保單編號）的主約與附約；手動加入的商品自己一張（2026-10-29 D21）
class PolicyGroup {
  final String key;
  final String companyName;
  final String? policyNumber;
  final DateTime? effectiveDate;
  // 主約在前，附約依原本順序
  final List<CustomerEnrolledPolicy> items;
  // 手動加入（沒有保單編號、保單號碼）的單一商品
  final bool isManual;

  const PolicyGroup({
    required this.key,
    required this.companyName,
    required this.policyNumber,
    required this.effectiveDate,
    required this.items,
    required this.isManual,
  });

  /// 收合時顯示的那一項：主約；沒有主約就第一項
  CustomerEnrolledPolicy get mainItem => items.first;

  List<CustomerEnrolledPolicy> get otherItems => items.sublist(1);

  /// 整張都失效了（全部項目都是已失效）才放進「已失效保單」
  bool get isAllLapsed {
    for (final CustomerEnrolledPolicy item in items) {
      if (item.isActive) return false;
    }
    return true;
  }
}

/// 把客戶的保單（一個商品一筆）歸成一張一張的保單
class PolicyGrouping {
  /// 同一張保單的判斷：同保單編號（同一次掃描）→ 同公司同保單號碼 → 都沒有就自己一張；順序照第一次出現
  static List<PolicyGroup> group(List<CustomerEnrolledPolicy> policies) {
    final Map<String, List<CustomerEnrolledPolicy>> itemsByKey = {};
    for (final CustomerEnrolledPolicy policy in policies) {
      itemsByKey.putIfAbsent(_keyOf(policy), () => []).add(policy);
    }
    final List<PolicyGroup> groups = [];
    itemsByKey.forEach((String key, List<CustomerEnrolledPolicy> items) {
      groups.add(_buildGroup(key, items));
    });
    return groups;
  }

  static String _keyOf(CustomerEnrolledPolicy policy) {
    final String groupId = policy.policyGroupId ?? '';
    if (groupId.isNotEmpty) {
      return 'group:$groupId';
    }
    final String policyNumber = (policy.policyNumber ?? '').trim();
    if (policyNumber.isNotEmpty) {
      return 'number:${policy.companyName}:$policyNumber';
    }
    return 'single:${policy.id}';
  }

  static PolicyGroup _buildGroup(String key, List<CustomerEnrolledPolicy> items) {
    final List<CustomerEnrolledPolicy> mainItems = [];
    final List<CustomerEnrolledPolicy> otherItems = [];
    for (final CustomerEnrolledPolicy item in items) {
      if (item.coverageRole == 'main') {
        mainItems.add(item);
      } else {
        otherItems.add(item);
      }
    }
    final List<CustomerEnrolledPolicy> ordered = [...mainItems, ...otherItems];
    String? policyNumber;
    DateTime? effectiveDate;
    for (final CustomerEnrolledPolicy item in ordered) {
      policyNumber ??= item.policyNumber;
      effectiveDate ??= item.effectiveDate;
    }
    return PolicyGroup(
      key: key,
      companyName: ordered.first.companyName,
      policyNumber: policyNumber,
      effectiveDate: effectiveDate,
      items: ordered,
      isManual: key.startsWith('single:') && (policyNumber ?? '').isEmpty,
    );
  }
}
