import 'package:flutter/material.dart';
import '../services/customer_policy_service.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'insurance_product_card.dart';

/// 限額文字：沒有資料時顯示「建置中」，不顯示假數字
String limitTextOrNotReady(String limitText) {
  if (limitText.trim().isEmpty) {
    return '建置中';
  }
  return limitText;
}

/// 「加入保單」搜尋結果的一列：公司、險種、商品名稱、＋加入
class CatalogProductResultTile extends StatelessWidget {
  final InsuranceProduct product;
  final VoidCallback onEnroll;

  const CatalogProductResultTile({super.key, required this.product, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ProductInfoChip(text: product.companyName, highlighted: true),
                    ProductInfoChip(text: product.insuranceTypeLabel),
                    ProductInfoChip(text: product.productKindLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.productName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            onPressed: onEnroll,
            child: const Text('+ 加入', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// 保單狀態選擇：上排「有保障」、下排「沒有保障」（加保單、改狀態共用；2026-11-07 模型圖沛沛確認）
class PolicyStatusSelector extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const PolicyStatusSelector({super.key, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('有保障', style: TextStyle(fontSize: 11, color: colors.ok)),
        const SizedBox(height: 4),
        _StatusChoiceRow(statuses: PolicyStatus.withCoverage, selected: status, onChanged: onChanged),
        const SizedBox(height: 8),
        Text('沒有保障', style: TextStyle(fontSize: 11, color: colors.ink3)),
        const SizedBox(height: 4),
        _StatusChoiceRow(statuses: PolicyStatus.withoutCoverage, selected: status, onChanged: onChanged),
      ],
    );
  }
}

/// 一排狀態按鈕
class _StatusChoiceRow extends StatelessWidget {
  final List<String> statuses;
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusChoiceRow({required this.statuses, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = [];
    for (final String status in statuses) {
      chips.add(SelectableChoiceChip(
        label: PolicyStatus.label(status),
        isSelected: status == selected,
        onSelected: () => onChanged(status),
      ));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

/// 單選按鈕：選中的用主題色底＋主題色字（狀態、繳別共用；沛沛 11/07 實測：灰色選中看不出來）
class SelectableChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const SelectableChoiceChip({super.key, required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color textColor = colors.ink2;
    Color borderColor = colors.line;
    if (isSelected) {
      textColor = colors.acc;
      borderColor = colors.acc;
    }
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      selected: isSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: colors.accSoft,
      backgroundColor: colors.surface,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      onSelected: (bool selected) => onSelected(),
    );
  }
}

/// 保單狀態小標籤：有效綠、減額繳清／展期定期藍（有保障但和原本不同）、沒保障灰；停效多寫「可復效」
class PolicyStatusChip extends StatelessWidget {
  final String status;

  const PolicyStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color backgroundColor = colors.surface2;
    Color textColor = colors.ink3;
    String label = PolicyStatus.label(status);
    if (status == PolicyStatus.active) {
      backgroundColor = colors.okSoft;
      textColor = colors.ok;
    } else if (PolicyStatus.hasCoverage(status)) {
      backgroundColor = colors.accSoft;
      textColor = colors.acc;
    } else if (status == PolicyStatus.lapsed) {
      label = '停效・可復效';
    }
    return _SmallPill(label: label, backgroundColor: backgroundColor, textColor: textColor);
  }
}

/// 「有貸款」黃色小標籤（保單貸款是有效保單上的加註，不是狀態）
class PolicyLoanChip extends StatelessWidget {
  const PolicyLoanChip({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return _SmallPill(label: '有貸款', backgroundColor: colors.warnSoft, textColor: colors.warn);
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _SmallPill({required this.label, required this.backgroundColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

/// 側邊抽屜「已投保保單清單 (N 張)：」標題列＋「掃描保單」「搜尋商品加入」兩個按鈕
/// （2026-10-24 從 customer_detail_side_sheet.dart 拆出；手機寬度放不下時按鈕自動換行）
class EnrolledPoliciesHeader extends StatelessWidget {
  final int policyCount;
  final bool isSearchOpen;
  final String enrollButtonLabel;
  final VoidCallback onScanPressed;
  final VoidCallback onToggleSearch;

  const EnrolledPoliciesHeader({
    super.key,
    required this.policyCount,
    required this.isSearchOpen,
    required this.enrollButtonLabel,
    required this.onScanPressed,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    IconData searchIcon = Icons.add_rounded;
    String searchLabel = enrollButtonLabel;
    if (isSearchOpen) {
      searchIcon = Icons.close_rounded;
      searchLabel = '收合搜尋';
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text('已投保保單清單 ($policyCount 張)：',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        TextButton.icon(
          onPressed: onScanPressed,
          icon: const Icon(Icons.document_scanner_outlined, size: 16),
          label: const Text('掃描保單', style: TextStyle(fontSize: 11)),
        ),
        OutlinedButton.icon(
          onPressed: onToggleSearch,
          icon: Icon(searchIcon, size: 16),
          label: Text(searchLabel, style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: colors.acc, side: BorderSide(color: colors.acc)),
        ),
      ],
    );
  }
}
