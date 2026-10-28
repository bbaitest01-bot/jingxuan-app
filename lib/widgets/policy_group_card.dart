import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/customer_policy_service.dart';
import '../services/policy_group_service.dart';
import '../theme/app_theme.dart';
import 'custom_toast.dart';

/// 客戶的保單：一張保單一張卡片（2026-10-29 D21，視覺模型圖沛沛確認）
///
/// - 分「有效保單」「已失效保單」兩區；整張都失效才放已失效，部分附約失效的那幾項劃線
/// - 卡片預設只顯示主約，「＋N 項附約」點開才列出
/// - 點一項：看商品資料、保額、標為已失效／改回有效、刪除這項
/// - 「⋯」：整張標為已失效／改回有效、刪除整張保單
/// 客戶完整頁與側邊抽屜共用；onSetStatus、onDelete 給的是要處理的那幾項（一項或整張）
class PolicyGroupList extends StatelessWidget {
  final List<CustomerEnrolledPolicy> policies;
  final String emptyText;
  final ValueChanged<CustomerEnrolledPolicy> onOpenProduct;
  final ValueChanged<CustomerEnrolledPolicy> onEditCoverage;
  final void Function(List<CustomerEnrolledPolicy> items, String status) onSetStatus;
  final ValueChanged<List<CustomerEnrolledPolicy>> onDelete;

  const PolicyGroupList({
    super.key,
    required this.policies,
    required this.emptyText,
    required this.onOpenProduct,
    required this.onEditCoverage,
    required this.onSetStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    if (policies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(emptyText, style: TextStyle(fontSize: 12, color: colors.ink3), textAlign: TextAlign.center),
      );
    }
    final List<PolicyGroup> activeGroups = [];
    final List<PolicyGroup> lapsedGroups = [];
    for (final PolicyGroup group in PolicyGrouping.group(policies)) {
      if (group.isAllLapsed) {
        lapsedGroups.add(group);
      } else {
        activeGroups.add(group);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupSection(title: '有效保單', groups: activeGroups, list: this),
        const SizedBox(height: 14),
        _GroupSection(title: '已失效保單', groups: lapsedGroups, list: this),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final List<PolicyGroup> groups;
  final PolicyGroupList list;

  const _GroupSection({required this.title, required this.groups, required this.list});

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
      children.add(PolicyGroupCard(group: group, list: list));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// 一張保單的卡片
class PolicyGroupCard extends StatefulWidget {
  final PolicyGroup group;
  final PolicyGroupList list;

  const PolicyGroupCard({super.key, required this.group, required this.list});

  @override
  State<PolicyGroupCard> createState() => _PolicyGroupCardState();
}

class _PolicyGroupCardState extends State<PolicyGroupCard> {
  bool _isExpanded = false;

  PolicyGroup get _group => widget.group;

  String _subtitle() {
    if (_group.isManual) {
      return '手動加入';
    }
    final List<String> parts = [];
    final String policyNumber = _group.policyNumber ?? '';
    if (policyNumber.isNotEmpty) parts.add('保單號碼 $policyNumber');
    final DateTime? effectiveDate = _group.effectiveDate;
    if (effectiveDate != null) parts.add('生效 ${DateFormat('yyyy/MM/dd').format(effectiveDate)}');
    if (parts.isEmpty) return '掃描加入';
    return parts.join('・');
  }

  Future<void> _onGroupMenu(String action) async {
    final List<CustomerEnrolledPolicy> items = _group.items;
    if (action == 'lapse') {
      widget.list.onSetStatus(items, PolicyStatus.lapsed);
    } else if (action == 'active') {
      widget.list.onSetStatus(items, PolicyStatus.active);
    } else if (action == 'delete' && await _confirmDelete(context, '刪除整張保單', '會刪掉這張保單的 ${items.length} 項，刪除後無法復原。')) {
      widget.list.onDelete(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> rows = [_PolicyItemRow(item: _group.mainItem, list: widget.list)];
    final int otherCount = _group.otherItems.length;
    if (_isExpanded) {
      for (final CustomerEnrolledPolicy item in _group.otherItems) {
        rows.add(_PolicyItemRow(item: item, list: widget.list));
      }
    }
    String lapseLabel = '整張標為已失效';
    String lapseAction = 'lapse';
    if (_group.isAllLapsed) {
      lapseLabel = '整張改回有效';
      lapseAction = 'active';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_group.companyName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
                    Text(_subtitle(), style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: colors.ink3),
                tooltip: '整張保單',
                onSelected: _onGroupMenu,
                itemBuilder: (BuildContext menuContext) => [
                  PopupMenuItem<String>(value: lapseAction, child: Text(lapseLabel)),
                  PopupMenuItem<String>(value: 'delete', child: Text('刪除整張保單', style: TextStyle(color: colors.warn))),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
          if (otherCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16),
                label: Text(_isExpanded ? '收起' : '＋ $otherCount 項附約', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: colors.acc, padding: EdgeInsets.zero),
              ),
            ),
        ],
      ),
    );
  }
}

/// 保單裡的一項：標籤＋名稱＋保額或計畫（沒有就「補保額」）；已失效的劃線
class _PolicyItemRow extends StatelessWidget {
  final CustomerEnrolledPolicy item;
  final PolicyGroupList list;

  const _PolicyItemRow({required this.item, required this.list});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool isLapsed = !item.isActive;
    final String amountText = policyAmountText(item);
    Widget trailing = Text(amountText, style: AppTextStyles.mono(fontSize: 12, color: isLapsed ? colors.ink3 : colors.ink2));
    if (amountText.isEmpty) {
      trailing = InkWell(
        onTap: () => list.onEditCoverage(item),
        child: Text('補保額', style: TextStyle(fontSize: 12, color: colors.acc)),
      );
    }
    return InkWell(
      onTap: () => _showItemActions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 0.5))),
        child: Row(
          children: [
            _RoleTag(item: item),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.productName,
                style: TextStyle(
                  fontSize: 13,
                  color: isLapsed ? colors.ink3 : colors.ink,
                  decoration: isLapsed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  /// 點一項跳出的動作清單（手機與電腦共用）
  List<_ItemAction> _itemActions() {
    String statusLabel = '這項改回有效';
    if (item.isActive) statusLabel = '這項標為已失效';
    final List<_ItemAction> actions = [];
    if (item.isInCatalog) actions.add(const _ItemAction('open', '看商品資料', Icons.description_outlined));
    actions.add(const _ItemAction('coverage', '保障類別與保額', Icons.edit_outlined));
    actions.add(_ItemAction('status', statusLabel, Icons.swap_horiz_rounded));
    actions.add(const _ItemAction('delete', '刪除這項', Icons.delete_outline_rounded, isDanger: true));
    return actions;
  }

  // 手機（窄螢幕）從下方滑出；電腦在點的那一列旁邊跳出小選單（沛沛 10/29：電腦用底部滑出很奇怪）
  Future<void> _showItemActions(BuildContext context) async {
    String? action;
    if (MediaQuery.sizeOf(context).width < 600) {
      action = await _showActionSheet(context);
    } else {
      action = await _showActionMenu(context);
    }
    if (!context.mounted) return;
    if (action == 'open') {
      list.onOpenProduct(item);
    } else if (action == 'coverage') {
      list.onEditCoverage(item);
    } else if (action == 'status') {
      list.onSetStatus([item], item.isActive ? PolicyStatus.lapsed : PolicyStatus.active);
    } else if (action == 'delete' && await _confirmDelete(context, '刪除這項', '刪除「${item.productName}」，刪除後無法復原。')) {
      list.onDelete([item]);
    }
  }

  Future<String?> _showActionSheet(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> tiles = [
      ListTile(title: Text(item.productName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink))),
    ];
    for (final _ItemAction action in _itemActions()) {
      final Color? color = action.isDanger ? colors.warn : null;
      tiles.add(Builder(
        builder: (BuildContext tileContext) => ListTile(
          leading: Icon(action.icon, color: color),
          title: Text(action.label, style: TextStyle(color: color)),
          onTap: () => Navigator.pop(tileContext, action.value),
        ),
      ));
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      builder: (BuildContext sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: tiles)),
    );
  }

  // 選單貼在這一列的右下方
  Future<String?> _showActionMenu(BuildContext context) {
    final AppColors colors = context.appColors;
    final RenderBox rowBox = context.findRenderObject() as RenderBox;
    final RenderBox overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset rowBottomRight = rowBox.localToGlobal(rowBox.size.bottomRight(Offset.zero), ancestor: overlayBox);
    final RelativeRect position = RelativeRect.fromLTRB(
      rowBottomRight.dx - 200,
      rowBottomRight.dy,
      overlayBox.size.width - rowBottomRight.dx,
      0,
    );
    final List<PopupMenuEntry<String>> entries = [];
    for (final _ItemAction action in _itemActions()) {
      Color color = colors.ink;
      if (action.isDanger) color = colors.warn;
      entries.add(PopupMenuItem<String>(
        value: action.value,
        height: 40,
        child: Row(
          children: [
            Icon(action.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(action.label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ));
    }
    return showMenu<String>(
      context: context,
      position: position,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      items: entries,
    );
  }
}

/// 點一項時的一個動作（value 給程式判斷，label 給人看）
class _ItemAction {
  final String value;
  final String label;
  final IconData icon;
  final bool isDanger;

  const _ItemAction(this.value, this.label, this.icon, {this.isDanger = false});
}

/// 主約用主題色、附約淡灰、已失效虛框
class _RoleTag extends StatelessWidget {
  final CustomerEnrolledPolicy item;

  const _RoleTag({required this.item});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String label = '商品';
    if (item.coverageRole == 'main') label = '主約';
    if (item.coverageRole == 'rider') label = '附約';
    Color background = colors.surface2;
    Color textColor = colors.ink2;
    if (item.coverageRole == 'main' || item.coverageRole == null) {
      background = colors.accSoft;
      textColor = colors.acc;
    }
    if (!item.isActive) {
      label = '已失效';
      background = colors.surface;
      textColor = colors.ink3;
    }
    return Container(
      width: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: item.isActive ? null : Border.all(color: colors.line),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

/// 卡片右邊的金額：保額「100 萬」「35,000」；沒有保額用計畫（「計畫三」）；都沒有回傳空字串（顯示「補保額」）
String policyAmountText(CustomerEnrolledPolicy item) {
  final int? amount = item.coverageAmount;
  if (amount != null) {
    if (amount >= 10000 && amount % 1000 == 0) {
      String tenThousands = (amount / 10000).toStringAsFixed(1);
      if (tenThousands.endsWith('.0')) tenThousands = tenThousands.substring(0, tenThousands.length - 2);
      return '$tenThousands 萬';
    }
    return NumberFormat('#,###').format(amount);
  }
  return item.planOrAmount ?? '';
}

Future<bool> _confirmDelete(BuildContext context, String title, String message) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppColors colors = dialogContext.appColors;
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(title, style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        content: Text(message, style: TextStyle(fontSize: 13, color: colors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            style: AppButtonStyles.danger(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// 客戶完整頁與側邊抽屜共用：改狀態並跳提示；有改到回傳 true（呼叫的地方再重新讀保單）
Future<bool> savePolicyStatus(BuildContext context, String customerId, List<CustomerEnrolledPolicy> items, String status) async {
  final int successCount = await CustomerPolicyService().updateStatusForPolicies(customerId, items, status);
  if (!context.mounted) return successCount > 0;
  if (successCount < items.length) {
    CustomToast.show(context, '有 ${items.length - successCount} 項切換失敗，請檢查網路後再試', ToastType.error);
  } else {
    CustomToast.show(context, '已改為${PolicyStatus.label(status)}（${items.length} 項）', ToastType.success);
  }
  return successCount > 0;
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
