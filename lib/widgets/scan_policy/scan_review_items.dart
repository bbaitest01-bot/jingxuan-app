import 'package:flutter/material.dart';

import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';
import 'scan_review_panel.dart';

/// 掃描結果的商品清單與每一列（從 scan_review_panel.dart 拆出，維持 500 行內）

/// 商品清單：附約多時收起來，有問題（目錄找不到）的項目一律顯示
class ScanReviewItemList extends StatelessWidget {
  final List<ScannedPolicyItem> items;
  final bool isExpanded;
  final int collapsedVisibleCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onEditItem;
  final ValueChanged<int> onApplySuggestion;
  final ValueChanged<int> onUseRetakeValue;

  const ScanReviewItemList({
    super.key,
    required this.items,
    required this.isExpanded,
    required this.collapsedVisibleCount,
    required this.onToggleExpanded,
    required this.onEditItem,
    required this.onApplySuggestion,
    required this.onUseRetakeValue,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> rows = [];
    int hiddenCount = 0;
    for (int index = 0; index < items.length; index++) {
      final ScannedPolicyItem item = items[index];
      // 有問題、或補拍新增的項目一律顯示
      final bool canHide = index >= collapsedVisibleCount && item.isInCatalog && !item.addedByRetake && item.retakeAlternative == null;
      if (!isExpanded && canHide) {
        hiddenCount++;
        continue;
      }
      rows.add(_ScannedItemRow(
        item: item,
        isLast: index == items.length - 1 && hiddenCount == 0,
        onEdit: () => onEditItem(index),
        onApplySuggestion: () => onApplySuggestion(index),
        onUseRetakeValue: () => onUseRetakeValue(index),
      ));
    }
    final bool canCollapse = items.length > collapsedVisibleCount;
    if (canCollapse) {
      String toggleText = '收起';
      IconData toggleIcon = Icons.expand_less_rounded;
      if (!isExpanded) {
        toggleText = '另 $hiddenCount 項';
        toggleIcon = Icons.expand_more_rounded;
      }
      rows.add(InkWell(
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(toggleText, style: TextStyle(fontSize: 12, color: colors.ink2)),
              Icon(toggleIcon, size: 16, color: colors.ink2),
            ],
          ),
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

/// 商品一列：標籤＋名稱＋保額或計畫；目錄找不到的整列淡黃並說明，有建議時可「套用」
class _ScannedItemRow extends StatelessWidget {
  final ScannedPolicyItem item;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onApplySuggestion;
  final VoidCallback onUseRetakeValue;

  const _ScannedItemRow({
    required this.item,
    required this.isLast,
    required this.onEdit,
    required this.onApplySuggestion,
    required this.onUseRetakeValue,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final ScannedPolicyItem? retakeAlternative = item.retakeAlternative;
    final bool hasProblem = !item.isInCatalog || retakeAlternative != null;
    final String plan = item.planOrAmount ?? '';
    final int? premium = item.premium;
    final List<Widget> lines = [
      Row(
        children: [
          _CoverageRoleTag(role: item.coverageRole),
          const SizedBox(width: 8),
          Expanded(child: Text(item.productName, style: TextStyle(fontSize: 13, color: colors.ink))),
          if (item.addedByRetake) ...[
            const SizedBox(width: 6),
            Text('補拍新增', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.ok)),
          ],
          if (plan.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(plan, style: AppTextStyles.mono(fontSize: 12, color: colors.ink2)),
          ],
        ],
      ),
    ];
    if (premium != null) {
      lines.add(Padding(
        padding: const EdgeInsets.only(left: 44, top: 2),
        child: Text(formatPremiumText(premium, item.premiumCurrency), style: TextStyle(fontSize: 11, color: colors.ink3)),
      ));
    }
    if (retakeAlternative != null) {
      lines.add(_RetakeConflictLine(alternative: retakeAlternative, onUse: onUseRetakeValue));
    }
    if (!item.isInCatalog) {
      lines.add(_NotInCatalogLine(
        suggestedName: item.suggestedProduct?.productName,
        onApplySuggestion: onApplySuggestion,
      ));
    }
    return Material(
      color: hasProblem ? colors.warnSoft : colors.surface,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: colors.line, width: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines),
        ),
      ),
    );
  }
}

/// 「主約／附約」小標籤：主約用主題色，附約用淡灰
class _CoverageRoleTag extends StatelessWidget {
  final String? role;

  const _CoverageRoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String label = '商品';
    Color backgroundColor = colors.surface2;
    Color textColor = colors.ink2;
    if (role == 'main') {
      label = '主約';
      backgroundColor = colors.accSoft;
      textColor = colors.acc;
    } else if (role == 'rider') {
      label = '附約';
    }
    return Container(
      width: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

/// 目錄找不到：「目錄找不到，仍會存入」；AI 可能讀錯字時多一個「可能是：XXX 套用」（按了才換）
class _NotInCatalogLine extends StatelessWidget {
  final String? suggestedName;
  final VoidCallback onApplySuggestion;

  const _NotInCatalogLine({required this.suggestedName, required this.onApplySuggestion});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? suggestion = suggestedName;
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text('目錄找不到，仍會存入', style: TextStyle(fontSize: 11, color: colors.warn)),
          if (suggestion != null) ...[
            Text('可能是：$suggestion', style: TextStyle(fontSize: 11, color: colors.warn)),
            InkWell(
              onTap: onApplySuggestion,
              child: Text(
                '套用',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 補拍讀到的金額或計畫不一樣：顯示補拍的值，按「改用補拍的」才換（不按就保留第一次的）
class _RetakeConflictLine extends StatelessWidget {
  final ScannedPolicyItem alternative;
  final VoidCallback onUse;

  const _RetakeConflictLine({required this.alternative, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> values = [];
    final String plan = alternative.planOrAmount ?? '';
    if (plan.isNotEmpty) values.add(plan);
    final int? premium = alternative.premium;
    if (premium != null) values.add(formatPremiumText(premium, alternative.premiumCurrency));
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text('補拍讀到：${values.join('・')}', style: TextStyle(fontSize: 11, color: colors.warn)),
          InkWell(
            onTap: onUse,
            child: Text(
              '改用補拍的',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}
