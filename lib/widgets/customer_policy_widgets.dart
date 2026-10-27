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

/// 客戶「保單健檢與缺口」的理賠總額卡片
///
/// 只加總有理賠限額資料的保單；真實商品還沒有第二層比價資料，會列在「未納入計算」。
class BenefitSummaryCard extends StatelessWidget {
  final CustomerBenefitSummary? summary;

  const BenefitSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final int countedCount = summary?.countedPolicyCount ?? 0;
    final int notCountedCount = summary?.policiesWithoutLimitCount ?? 0;

    final List<Widget> rows = [];
    if (countedCount == 0) {
      rows.add(Text(
        '理賠限額資料建置中，暫時無法計算保障總額與缺口。',
        style: TextStyle(fontSize: 12, color: colors.ink3),
      ));
    } else {
      rows.add(_SummaryRow(label: '病房給付總額', value: '${summary!.totalRoomDaily} 元/日', icon: Icons.hotel_rounded));
      rows.add(
          _SummaryRow(label: '手術給付上限', value: '${summary!.totalSurgeryMax} 元', icon: Icons.medical_services_rounded));
      rows.add(_SummaryRow(label: '自費雜費總額', value: '${summary!.totalMiscMax} 元', icon: Icons.receipt_rounded));
      rows.add(_SummaryRow(
        label: '癌症重疾一次金',
        value: '${summary!.totalCancerCriticalMax ~/ 10000} 萬元',
        icon: Icons.coronavirus_rounded,
      ));
    }
    if (notCountedCount > 0) {
      rows.add(const SizedBox(height: 6));
      rows.add(Text(
        '$notCountedCount 張保單尚無理賠限額資料，未納入計算',
        style: TextStyle(fontSize: 11, color: colors.ink3),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.acc.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: colors.acc, size: 18),
              const SizedBox(width: 8),
              Text('理賠總額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.ink3),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: colors.ink2))),
          Text(value, style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink)),
        ],
      ),
    );
  }
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

/// 「有效／已失效」二選一（加保單時用；預設有效）
class PolicyStatusSelector extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const PolicyStatusSelector({super.key, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(value: PolicyStatus.active, label: Text('有效')),
        ButtonSegment<String>(value: PolicyStatus.lapsed, label: Text('已失效')),
      ],
      selected: {status},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (Set<String> selected) => onChanged(selected.first),
    );
  }
}

/// 保單狀態小標籤：有效用成功綠、已失效用灰
class PolicyStatusChip extends StatelessWidget {
  final String status;

  const PolicyStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color backgroundColor = colors.okSoft;
    Color textColor = colors.ok;
    if (status == PolicyStatus.lapsed) {
      backgroundColor = colors.surface2;
      textColor = colors.ink3;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(PolicyStatus.label(status),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

/// 側邊抽屜「已投保保單」的一列：狀態、商品、限額，右邊切換狀態與刪除
class EnrolledPolicyTile extends StatelessWidget {
  final CustomerEnrolledPolicy policy;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onOpenProduct;
  // 保單健檢（4-L）：編輯保障類別、保額、實支計畫；沒給就不顯示按鈕
  final VoidCallback? onEditCoverage;

  const EnrolledPolicyTile({
    super.key,
    required this.policy,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onOpenProduct,
    this.onEditCoverage,
  });

  /// 公司・險種・主約・計畫三（掃描保單才有主附約與計畫）
  String _companyLineText() {
    final List<String> parts = [policy.companyName, policy.category];
    if (policy.coverageRoleLabel.isNotEmpty) {
      parts.add(policy.coverageRoleLabel);
    }
    final String planOrAmount = policy.planOrAmount ?? '';
    if (planOrAmount.isNotEmpty) {
      parts.add(planOrAmount);
    }
    return parts.join('・');
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // 已失效的保單整列變淡，一眼就和有效保單分開
    Color nameColor = colors.ink;
    String toggleLabel = '標為已失效';
    if (!policy.isActive) {
      nameColor = colors.ink3;
      toggleLabel = '改回有效';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            // 點左邊的商品資訊，跳到數據戰情並帶出那款商品
            child: InkWell(
              onTap: onOpenProduct,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PolicyStatusChip(status: policy.status),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          policy.productName,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nameColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_companyLineText(), style: TextStyle(fontSize: 10, color: colors.ink3)),
                  if (!policy.isInCatalog)
                    Text('目錄中找不到此商品', style: TextStyle(fontSize: 10, color: colors.warn)),
                ],
              ),
            ),
          ),
          if (onEditCoverage != null)
            TextButton(
              onPressed: onEditCoverage,
              style: TextButton.styleFrom(
                foregroundColor: colors.acc,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
              ),
              child: const Text('保額', style: TextStyle(fontSize: 11)),
            ),
          TextButton(
            onPressed: onToggleStatus,
            style: TextButton.styleFrom(
              foregroundColor: colors.acc,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
            ),
            child: Text(toggleLabel, style: const TextStyle(fontSize: 11)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: Theme.of(context).colorScheme.error,
            tooltip: '刪除這張保單',
            onPressed: onDelete,
          ),
        ],
      ),
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

/// 側邊抽屜的已投保保單清單；沒有保單時顯示提示文字
/// （2026-10-24 從 customer_detail_side_sheet.dart 拆出）
class EnrolledPolicyList extends StatelessWidget {
  final List<CustomerEnrolledPolicy> policies;
  final String emptyText;
  final ValueChanged<CustomerEnrolledPolicy> onToggleStatus;
  final ValueChanged<CustomerEnrolledPolicy> onOpenProduct;
  final ValueChanged<CustomerEnrolledPolicy> onDelete;
  final ValueChanged<CustomerEnrolledPolicy> onEditCoverage;

  const EnrolledPolicyList({
    super.key,
    required this.policies,
    required this.emptyText,
    required this.onToggleStatus,
    required this.onOpenProduct,
    required this.onDelete,
    required this.onEditCoverage,
  });

  @override
  Widget build(BuildContext context) {
    if (policies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText,
              style: TextStyle(fontSize: 12, color: context.appColors.ink3), textAlign: TextAlign.center),
        ),
      );
    }
    final List<Widget> tiles = [];
    for (final CustomerEnrolledPolicy policy in policies) {
      if (tiles.isNotEmpty) {
        tiles.add(const SizedBox(height: 8));
      }
      tiles.add(EnrolledPolicyTile(
        policy: policy,
        onToggleStatus: () => onToggleStatus(policy),
        onOpenProduct: () => onOpenProduct(policy),
        onDelete: () => onDelete(policy),
        onEditCoverage: () => onEditCoverage(policy),
      ));
    }
    return Column(children: tiles);
  }
}
