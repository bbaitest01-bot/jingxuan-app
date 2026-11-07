import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../services/customer_policy_service.dart';
import '../../services/policy_detail_service.dart';
import '../../services/policy_group_service.dart';
import '../../services/policy_party_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import '../policy_group_card.dart';

/// 客戶的保單清單（2026-10-29 D21；2026-11-07 加上方摘要、狀態細分，模型圖沛沛確認）
///
/// - 最上面：有效保單張數、一年總保費
/// - 分「有效保單」「已失效保單」兩區；整張都沒保障才放已失效，部分附約失效的那幾項劃線
/// - 卡片「編輯」改三個人、保費、繳別、生效日；「⋯」改狀態、刪除
/// - 最下面「保障他的保單」：別的客戶當要保人、被保險人是這位客戶的保單（例：媽媽幫他買的）
/// 客戶完整頁與側邊抽屜共用；改了保單資料或狀態會呼叫 onPolicyChanged（呼叫的地方重新讀保單）
class PolicyGroupList extends StatefulWidget {
  final String customerId;
  final List<CustomerEnrolledPolicy> policies;
  final String emptyText;
  final ValueChanged<CustomerEnrolledPolicy> onOpenProduct;
  final ValueChanged<CustomerEnrolledPolicy> onEditCoverage;
  final VoidCallback onPolicyChanged;
  final ValueChanged<List<CustomerEnrolledPolicy>> onDelete;

  const PolicyGroupList({
    super.key,
    required this.customerId,
    required this.policies,
    required this.emptyText,
    required this.onOpenProduct,
    required this.onEditCoverage,
    required this.onPolicyChanged,
    required this.onDelete,
  });

  @override
  State<PolicyGroupList> createState() => _PolicyGroupListState();
}

class _PolicyGroupListState extends State<PolicyGroupList> {
  // 卡片上「要保人 王美華・被保險人 陳小寶」要用的名字
  Map<String, String> _partyNames = {};
  // 別人名下、但保障這位客戶的保單
  List<CustomerEnrolledPolicy> _policiesFromOthers = [];

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  @override
  void didUpdateWidget(PolicyGroupList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policies != widget.policies || oldWidget.customerId != widget.customerId) _loadParties();
  }

  Future<void> _loadParties() async {
    final PolicyPartyService service = PolicyPartyService();
    final List<CustomerEnrolledPolicy> fromOthers = await service.fetchPoliciesFromOthers(widget.customerId);
    final Map<String, String> names = await service.fetchNamesFor([...widget.policies, ...fromOthers]);
    if (!mounted) return;
    setState(() {
      _policiesFromOthers = fromOthers;
      _partyNames = names;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<CustomerEnrolledPolicy> policies = widget.policies;
    final Widget fromOthersSection = _CoveredByOthersSection(policies: _policiesFromOthers, names: _partyNames);
    if (policies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.emptyText, style: TextStyle(fontSize: 12, color: colors.ink3), textAlign: TextAlign.center),
          ),
          fromOthersSection,
        ],
      );
    }
    final List<PolicyGroup> activeGroups = [];
    final List<PolicyGroup> inactiveGroups = [];
    for (final PolicyGroup group in PolicyGrouping.group(policies)) {
      if (group.isAllLapsed) {
        inactiveGroups.add(group);
      } else {
        activeGroups.add(group);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PolicySummaryHeader(activeGroupCount: activeGroups.length, summary: PolicyDetailService.summarize(policies)),
        const SizedBox(height: 14),
        _GroupSection(title: '有效保單', groups: activeGroups, list: widget, partyNames: _partyNames),
        const SizedBox(height: 14),
        _GroupSection(title: '已失效保單', groups: inactiveGroups, list: widget, partyNames: _partyNames),
        fromOthersSection,
      ],
    );
  }
}

/// 「保障他的保單」：別的客戶當要保人買的；點要保人名字跳到那位客戶
class _CoveredByOthersSection extends StatelessWidget {
  final List<CustomerEnrolledPolicy> policies;
  final Map<String, String> names;

  const _CoveredByOthersSection({required this.policies, required this.names});

  @override
  Widget build(BuildContext context) {
    if (policies.isEmpty) return const SizedBox.shrink();
    final AppColors colors = context.appColors;
    final List<Widget> rows = [
      const SizedBox(height: 14),
      Text('保障他的保單（別人當要保人）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
      Text('健檢已經把這些算進來；要修改請到要保人的客戶頁', style: TextStyle(fontSize: 11, color: colors.ink3)),
    ];
    for (final CustomerEnrolledPolicy policy in policies) {
      final String policyholderId = policy.effectivePolicyholderId;
      final String policyholderName = names[policyholderId] ?? '';
      rows.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Expanded(child: Text(policy.productName, style: TextStyle(fontSize: 13, color: colors.ink))),
            InkWell(
              onTap: () => context.go(AppRoutes.customerPath(policyholderId)),
              child: Text('要保人 $policyholderName', style: TextStyle(fontSize: 12, color: colors.acc)),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// 保單區最上面的兩格摘要：有效保單幾張、一年總保費
class PolicySummaryHeader extends StatelessWidget {
  final int activeGroupCount;
  final AnnualPremiumSummary summary;

  const PolicySummaryHeader({super.key, required this.activeGroupCount, required this.summary});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String premiumText = PolicyDetailService.formatAnnualTotal(summary);
    // 保費有填、只差繳別時寫清楚缺什麼（沛沛 11/07：「還沒填」會以為保費沒填）
    if (premiumText.isEmpty && summary.missingFrequencyGroupCount > 0) premiumText = '補繳別後才會算';
    if (premiumText.isEmpty && summary.hasPayingPolicy) premiumText = '還沒填';
    if (premiumText.isEmpty) premiumText = '不用繳';
    String? note;
    if (summary.missingFrequencyGroupCount > 0) {
      note = '${summary.missingFrequencyGroupCount} 張還沒填繳別，沒算進去';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SummaryTile(label: '有效保單', value: '$activeGroupCount 張')),
            const SizedBox(width: 8),
            Expanded(child: _SummaryTile(label: '一年總保費', value: premiumText)),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(note, style: TextStyle(fontSize: 11, color: colors.warn)),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.mono(fontSize: 16, fontWeight: FontWeight.bold, color: colors.ink)),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final List<PolicyGroup> groups;
  final PolicyGroupList list;
  final Map<String, String> partyNames;

  const _GroupSection({required this.title, required this.groups, required this.list, required this.partyNames});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    int itemCount = 0;
    for (final PolicyGroup group in groups) {
      itemCount += group.items.length;
    }
    final List<Widget> children = [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink))),
          Text('${groups.length} 張保單・$itemCount 項', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ],
      ),
    ];
    if (groups.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('沒有', style: TextStyle(fontSize: 12, color: colors.ink3)),
      ));
    }
    for (final PolicyGroup group in groups) {
      children.add(const SizedBox(height: 8));
      children.add(PolicyGroupCard(group: group, list: list, partyNames: partyNames));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// 客戶完整頁與側邊抽屜共用：刪除並跳提示；有刪到回傳 true
Future<bool> deletePolicyItems(BuildContext context, String customerId, List<CustomerEnrolledPolicy> items) async {
  final int successCount = await CustomerPolicyService().removePoliciesForCustomer(customerId, items);
  if (!context.mounted) return successCount > 0;
  if (successCount < items.length) {
    CustomToast.show(context, '有 ${items.length - successCount} 項刪除失敗，請檢查網路後再試', ToastType.error);
  } else {
    CustomToast.show(context, '已刪除 ${items.length} 項', ToastType.success);
  }
  return successCount > 0;
}
