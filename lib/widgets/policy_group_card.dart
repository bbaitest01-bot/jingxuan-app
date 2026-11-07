import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/customer_policy_service.dart';
import '../services/policy_detail_service.dart';
import '../services/policy_group_service.dart';
import '../theme/app_theme.dart';
import 'customer_policy_widgets.dart';
import 'policy_detail/policy_group_list.dart';
import 'policy_detail/policy_premium_dialog.dart';
import 'policy_detail/policy_status_dialog.dart';

/// 一張保單的卡片（D21；2026-11-07 加狀態標籤、保費、繳別）
/// - 卡片預設只顯示主約，「＋N 項附約」點開才列出
/// - 右上「編輯」：保費、繳別、生效日；「⋯」：更改狀態、刪除整張保單
/// - 點一項：看商品資料、保額、更改這項狀態、刪除這項
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

  /// 「保單號碼 X・生效 2021/03/15・月繳・一年 24,600 元」；手動加入的開頭寫「手動加入」
  String _subtitle() {
    final List<String> parts = [];
    if (_group.isManual) parts.add('手動加入');
    final String policyNumber = _group.policyNumber ?? '';
    if (policyNumber.isNotEmpty) parts.add('保單號碼 $policyNumber');
    final DateTime? effectiveDate = _group.effectiveDate;
    if (effectiveDate != null) parts.add('生效 ${DateFormat('yyyy/MM/dd').format(effectiveDate)}');
    final String frequencyLabel = PaymentFrequency.label(_group.mainItem.paymentFrequency);
    if (frequencyLabel.isNotEmpty) parts.add(frequencyLabel);
    final String annualText = PolicyDetailService.formatAnnualTotal(PolicyDetailService.summarize(_group.items));
    if (annualText.isNotEmpty) parts.add('一年 $annualText');
    if (parts.isEmpty) return '掃描加入';
    return parts.join('・');
  }

  /// 還沒填的保單資料提醒：「還沒填繳別、生效日」；都填了回傳 null
  String? _missingDetailText() {
    // 已經沒有保障的保單（停效、解約、滿期）不必提醒
    if (_group.isAllLapsed) return null;
    final List<String> missing = [];
    if (_group.mainItem.paymentFrequency == null) missing.add('繳別');
    if (_group.effectiveDate == null) missing.add('生效日');
    if (missing.isEmpty) return null;
    return '還沒填${missing.join('、')}';
  }

  Future<void> _openPremiumDialog() async {
    if (await showPolicyPremiumDialog(context, _group.mainItem.customerId, _group.items)) widget.list.onPolicyChanged();
  }

  Future<void> _onGroupMenu(String action) async {
    final List<CustomerEnrolledPolicy> items = _group.items;
    if (action == 'status') {
      if (await showPolicyStatusDialog(context, _group.mainItem.customerId, items)) widget.list.onPolicyChanged();
    } else if (action == 'premium') {
      await _openPremiumDialog();
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
    final String? missingDetailText = _missingDetailText();
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
                    _GroupTitleRow(group: _group),
                    Text(_subtitle(), style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
                    if (missingDetailText != null)
                      Text(missingDetailText, style: TextStyle(fontSize: 11, color: colors.warn)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openPremiumDialog,
                style: TextButton.styleFrom(foregroundColor: colors.acc, visualDensity: VisualDensity.compact),
                child: const Text('編輯', style: TextStyle(fontSize: 12)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: colors.ink3),
                tooltip: '整張保單',
                onSelected: _onGroupMenu,
                itemBuilder: (BuildContext menuContext) => [
                  const PopupMenuItem<String>(value: 'premium', child: Text('保費、繳別、生效日')),
                  const PopupMenuItem<String>(value: 'status', child: Text('更改狀態')),
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
    final Widget trailing = _ItemAmountColumn(item: item, amountText: amountText, onFillAmount: () => list.onEditCoverage(item));
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
    final List<_ItemAction> actions = [];
    if (item.isInCatalog) actions.add(const _ItemAction('open', '看商品資料', Icons.description_outlined));
    actions.add(const _ItemAction('coverage', '保障類別與保額', Icons.edit_outlined));
    actions.add(const _ItemAction('status', '更改這項狀態', Icons.swap_horiz_rounded));
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
      if (await showPolicyStatusDialog(context, item.customerId, [item])) list.onPolicyChanged();
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
      label = PolicyStatus.label(item.status);
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
    return PolicyDetailService.formatAmount(amount);
  }
  return item.planOrAmount ?? '';
}

/// 卡片標題列：公司名稱＋狀態標籤（＋有貸款）
class _GroupTitleRow extends StatelessWidget {
  final PolicyGroup group;

  const _GroupTitleRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    bool hasPolicyLoan = false;
    for (final CustomerEnrolledPolicy item in group.items) {
      if (item.hasPolicyLoan) hasPolicyLoan = true;
    }
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(group.companyName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
        PolicyStatusChip(status: group.mainItem.status),
        if (hasPolicyLoan) const PolicyLoanChip(),
      ],
    );
  }
}

/// 一項右邊的金額：第一行保額（沒有就「補保額」；減額繳清寫「~~50 萬~~ 降為 20 萬」），第二行「每期 1,500 元」
class _ItemAmountColumn extends StatelessWidget {
  final CustomerEnrolledPolicy item;
  final String amountText;
  final VoidCallback onFillAmount;

  const _ItemAmountColumn({required this.item, required this.amountText, required this.onFillAmount});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color amountColor = colors.ink2;
    if (!item.isActive) amountColor = colors.ink3;
    Widget amountLine = Text(amountText, style: AppTextStyles.mono(fontSize: 12, color: amountColor));
    if (amountText.isEmpty) {
      amountLine = InkWell(
        onTap: onFillAmount,
        child: Text('補保額', style: TextStyle(fontSize: 12, color: colors.acc)),
      );
    }
    final int? reducedAmount = item.reducedCoverageAmount;
    if (item.status == PolicyStatus.reducedPaidUp && reducedAmount != null) {
      amountLine = Text.rich(
        TextSpan(children: [
          TextSpan(text: amountText, style: const TextStyle(decoration: TextDecoration.lineThrough)),
          TextSpan(text: ' 降為 ${PolicyDetailService.formatAmount(reducedAmount)}'),
        ]),
        style: AppTextStyles.mono(fontSize: 12, color: amountColor),
      );
    }
    final int? premium = item.premium;
    if (premium == null) return amountLine;
    final String premiumText = PolicyDetailService.formatPremium(premium, PolicyDetailService.currencyOf(item));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        amountLine,
        Text('每期 $premiumText', style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
      ],
    );
  }
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
