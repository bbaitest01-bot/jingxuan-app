import 'package:flutter/material.dart';

import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';
import '../customer_policy_widgets.dart';

/// 掃描保單第 ④ 步：確認／修正辨識結果，選有效／已失效，再存入
///
/// 每個商品標示「已對到商品目錄 ✓」或「目錄中找不到此商品，仍會存入」（2026-10-24 模型圖）
class ScanReviewPanel extends StatelessWidget {
  final String customerName;
  final ScannedPolicy policy;
  final String status;
  final bool isSaving;
  final ValueChanged<int> onEditItem;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback onAddItem;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRescan;
  final VoidCallback onSave;

  const ScanReviewPanel({
    super.key,
    required this.customerName,
    required this.policy,
    required this.status,
    required this.isSaving,
    required this.onEditItem,
    required this.onRemoveItem,
    required this.onAddItem,
    required this.onStatusChanged,
    required this.onRescan,
    required this.onSave,
  });

  /// 標題下的一行摘要：客戶・公司・生效日・保單號碼（沒讀到的就不顯示）
  String _summaryText() {
    final List<String> parts = [customerName];
    final String companyName = PolicyScanService.companyShortNames[policy.companyCode] ?? policy.companyName ?? '';
    if (companyName.isNotEmpty) {
      parts.add(companyName);
    }
    final DateTime? effectiveDate = policy.effectiveDate;
    if (effectiveDate != null) {
      final String month = effectiveDate.month.toString().padLeft(2, '0');
      final String day = effectiveDate.day.toString().padLeft(2, '0');
      parts.add('生效日 ${effectiveDate.year}/$month/$day');
    }
    final String policyNumber = policy.policyNumber ?? '';
    if (policyNumber.isNotEmpty) {
      parts.add('保單號碼 $policyNumber');
    }
    return parts.join('・');
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> itemRows = [];
    for (int index = 0; index < policy.items.length; index++) {
      itemRows.add(_ScannedItemRow(
        item: policy.items[index],
        onEdit: () => onEditItem(index),
        onRemove: () => onRemoveItem(index),
      ));
      itemRows.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_summaryText(), style: TextStyle(fontSize: 13, color: colors.ink2)),
        const SizedBox(height: 4),
        Text('請對照保單檢查，點商品可以修改', style: TextStyle(fontSize: 12, color: colors.ink3)),
        const SizedBox(height: 12),
        ...itemRows,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('補上漏掉的商品'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('保單狀態：', style: TextStyle(fontSize: 13, color: colors.ink2)),
            PolicyStatusSelector(status: status, onChanged: onStatusChanged),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isSaving || policy.items.isEmpty ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: Text(isSaving ? '存入中…' : '存入客戶保單（${policy.items.length} 項）'),
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: isSaving ? null : onRescan, child: const Text('辨識得不好？重新拍攝')),
      ],
    );
  }
}

class _ScannedItemRow extends StatelessWidget {
  final ScannedPolicyItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ScannedItemRow({required this.item, required this.onEdit, required this.onRemove});

  String _detailText() {
    final List<String> parts = [];
    final String plan = item.planOrAmount ?? '';
    if (plan.isNotEmpty) {
      parts.add(plan);
    }
    final int? premium = item.premium;
    if (premium != null) {
      parts.add('保費 $premium 元');
    }
    return parts.join('・');
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String detailText = _detailText();
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CoverageRoleTag(role: item.coverageRole, isInCatalog: item.isInCatalog),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item.productName, style: TextStyle(fontSize: 13, color: colors.ink)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _CatalogMatchLine(detailText: detailText, isInCatalog: item.isInCatalog),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: colors.ink3,
                tooltip: '修改',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: colors.ink3,
                tooltip: '刪除這項',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「主約／附約」小標籤：對到目錄用綠色，找不到用橘色
class _CoverageRoleTag extends StatelessWidget {
  final String? role;
  final bool isInCatalog;

  const _CoverageRoleTag({required this.role, required this.isInCatalog});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String label = '商品';
    if (role == 'main') {
      label = '主約';
    } else if (role == 'rider') {
      label = '附約';
    }
    Color backgroundColor = colors.okSoft;
    Color textColor = colors.ok;
    if (!isInCatalog) {
      backgroundColor = colors.warnSoft;
      textColor = colors.warn;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

class _CatalogMatchLine extends StatelessWidget {
  final String detailText;
  final bool isInCatalog;

  const _CatalogMatchLine({required this.detailText, required this.isInCatalog});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String matchText = '已對到商品目錄 ✓';
    Color matchColor = colors.ink3;
    if (!isInCatalog) {
      matchText = '目錄中找不到此商品，仍會存入';
      matchColor = colors.warn;
    }
    final List<InlineSpan> spans = [];
    if (detailText.isNotEmpty) {
      spans.add(TextSpan(text: '$detailText・', style: TextStyle(color: colors.ink3)));
    }
    spans.add(TextSpan(text: matchText, style: TextStyle(color: matchColor)));
    return Text.rich(TextSpan(style: const TextStyle(fontSize: 12), children: spans));
  }
}
