import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../models/visit_record.dart';
import '../../../router/app_routes.dart';
import '../../../services/customer_policy_service.dart';
import '../../../services/customer_service.dart';
import '../../visit_records/visit_record_widgets.dart';
import '../../../theme/app_theme.dart';
import '../customer_status_widgets.dart';

/// 客戶細節頁的一個區塊外框：標題（含筆數）、右上角按鈕、內容
class CustomerDetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  const CustomerDetailSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = context.appColors.acc;
    final Widget? actionWidget = action;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (actionWidget != null) actionWidget,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 沒有資料時的灰字提示
class CustomerDetailEmptyText extends StatelessWidget {
  final String text;

  const CustomerDetailEmptyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: context.appColors.ink3)),
    );
  }
}

/// 基本資料：電話、Email、標籤、備註、自訂欄位
class CustomerBasicInfoSection extends StatelessWidget {
  final Map<String, dynamic> customer;

  const CustomerBasicInfoSection({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final List<String> tags = List<String>.from(customer['tags'] ?? []);
    final String notes = customer['notes']?.toString() ?? '';
    final Map<String, dynamic> customAttributes =
        Map<String, dynamic>.from(customer['custom_attributes'] as Map? ?? {});

    final List<Widget> rows = [
      _InfoRow(label: '電話', value: customer['phone']?.toString() ?? ''),
      _InfoRow(label: 'Email', value: customer['email']?.toString() ?? ''),
      _InfoRow(label: '性別', value: CustomerService.genderLabel(customer['gender'] as String?)),
      _StatusRow(customerId: customer['id']?.toString() ?? '', status: customer['client_status'] as String?),
    ];
    // 匯入時帶進來的自訂欄位（例：生日、職業）
    for (final MapEntry<String, dynamic> entry in customAttributes.entries) {
      rows.add(_InfoRow(label: entry.key, value: entry.value?.toString() ?? ''));
    }

    return CustomerDetailSection(
      icon: Icons.badge_outlined,
      title: '基本資料',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          const SizedBox(height: 8),
          Text('標籤', style: TextStyle(fontSize: 12, color: context.appColors.ink3)),
          const SizedBox(height: 6),
          if (tags.isEmpty) const CustomerDetailEmptyText('沒有標籤'),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList(),
            ),
          const SizedBox(height: 12),
          Text('備註', style: TextStyle(fontSize: 12, color: context.appColors.ink3)),
          const SizedBox(height: 6),
          if (notes.trim().isEmpty) const CustomerDetailEmptyText('沒有備註'),
          if (notes.trim().isNotEmpty) SelectableText(notes, style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

/// 客戶狀態一列：狀態＋來源（例：「✔ 有意願／已成交（日常拜訪，10/14）」，4-2b）
class _StatusRow extends StatelessWidget {
  final String customerId;
  final String? status;

  const _StatusRow({required this.customerId, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('客戶狀態', style: TextStyle(fontSize: 13, color: context.appColors.ink3))),
          Expanded(child: CustomerStatusSourceText(customerId: customerId, status: status)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final String displayValue = value.trim().isEmpty ? '未填寫' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 13, color: context.appColors.ink3))),
          Expanded(child: SelectableText(displayValue, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// 保單（C6、C-18）：分「有效保單」「已失效保單」兩區，各自依險種分組；點一筆跳到數據戰情並帶出那款商品；狀態在快速預覽切換
class CustomerPoliciesSection extends StatelessWidget {
  final List<CustomerEnrolledPolicy> policies;
  // 右上角「掃描保單」（第 5 階段 E）
  final VoidCallback onScanPressed;
  // 保單健檢（4-L）：按保單上的「保額」編輯保障類別、保額、實支計畫
  final ValueChanged<CustomerEnrolledPolicy> onEditCoverage;

  const CustomerPoliciesSection({
    super.key,
    required this.policies,
    required this.onScanPressed,
    required this.onEditCoverage,
  });

  @override
  Widget build(BuildContext context) {
    final List<CustomerEnrolledPolicy> activePolicies = [];
    final List<CustomerEnrolledPolicy> lapsedPolicies = [];
    for (final CustomerEnrolledPolicy policy in policies) {
      if (policy.isActive) {
        activePolicies.add(policy);
      } else {
        lapsedPolicies.add(policy);
      }
    }

    Widget content = const CustomerDetailEmptyText('還沒有保單，可以按右上角「掃描保單」，或在數據戰情「＋加到客戶」加入');
    if (policies.isNotEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PolicyStatusGroup(title: '有效保單', policies: activePolicies, onEditCoverage: onEditCoverage),
          const SizedBox(height: 12),
          _PolicyStatusGroup(title: '已失效保單', policies: lapsedPolicies, onEditCoverage: onEditCoverage),
        ],
      );
    }

    return CustomerDetailSection(
      icon: Icons.health_and_safety_outlined,
      title: '保單（${policies.length}）',
      action: TextButton.icon(
        onPressed: onScanPressed,
        icon: const Icon(Icons.document_scanner_outlined, size: 18),
        label: const Text('掃描保單'),
      ),
      child: content,
    );
  }
}

/// 一個狀態區（例如「有效保單（2）」），底下依險種分組
class _PolicyStatusGroup extends StatelessWidget {
  final String title;
  final List<CustomerEnrolledPolicy> policies;
  final ValueChanged<CustomerEnrolledPolicy> onEditCoverage;

  const _PolicyStatusGroup({required this.title, required this.policies, required this.onEditCoverage});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> children = [
      Text('$title（${policies.length}）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
    ];
    if (policies.isEmpty) {
      children.add(const CustomerDetailEmptyText('沒有'));
    }

    final Map<String, List<CustomerEnrolledPolicy>> groups = CustomerPolicyService.groupPoliciesByCategory(policies);
    groups.forEach((String category, List<CustomerEnrolledPolicy> categoryPolicies) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.acc)),
      ));
      for (final CustomerEnrolledPolicy policy in categoryPolicies) {
        children.add(_PolicyRow(policy: policy, onEditCoverage: () => onEditCoverage(policy)));
      }
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _PolicyRow extends StatelessWidget {
  final CustomerEnrolledPolicy policy;
  final VoidCallback onEditCoverage;

  const _PolicyRow({required this.policy, required this.onEditCoverage});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color nameColor = colors.ink;
    if (!policy.isActive) {
      nameColor = colors.ink3;
    }
    // 公司 · 主約 · 計畫三 · 加入於…（掃描保單才有主附約與計畫）
    final List<String> subtitleParts = [policy.companyName];
    if (policy.coverageRoleLabel.isNotEmpty) {
      subtitleParts.add(policy.coverageRoleLabel);
    }
    final String planOrAmount = policy.planOrAmount ?? '';
    if (planOrAmount.isNotEmpty) {
      subtitleParts.add(planOrAmount);
    }
    final int? coverageAmount = policy.coverageAmount;
    if (coverageAmount != null) {
      subtitleParts.add('保額 ${formatCoverageAmount(coverageAmount)}');
    }
    subtitleParts.add('加入於 ${formatVisitRecordTime(policy.enrolledAt)}');
    final Widget coverageButton = TextButton(onPressed: onEditCoverage, child: const Text('保額'));

    // 目錄找不到的商品沒辦法跳到數據戰情，改標示「目錄中找不到」
    if (!policy.isInCatalog) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.description_outlined),
        title: Text(policy.productName, style: TextStyle(color: nameColor)),
        subtitle: Text('${subtitleParts.join(' · ')}\n目錄中找不到此商品', style: TextStyle(color: colors.ink3)),
        trailing: coverageButton,
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.description_outlined),
      title: Text(policy.productName, style: TextStyle(color: nameColor)),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [coverageButton, const Icon(Icons.chevron_right_rounded)],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      // 跳到數據戰情並帶出這款商品（已勾選），不用再自己搜尋
      onTap: () => context.go(AppRoutes.insightsProductPath(policy.policyClauseId)),
    );
  }
}

/// 拜訪紀錄（C7）：列出連結此客戶的拜訪紀錄，點一篇打開單篇頁
class CustomerVisitRecordsSection extends StatelessWidget {
  final List<VisitRecord> records;

  const CustomerVisitRecordsSection({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];
    for (final VisitRecord record in records) {
      items.add(ListTile(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.record_voice_over_outlined),
        title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          record.previewText.isEmpty ? '（沒有內容）' : record.previewText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: VisitRecordStatusChip(record: record),
        onTap: () => context.go(AppRoutes.visitRecordPath(record.id)),
      ));
    }

    return CustomerDetailSection(
      icon: Icons.record_voice_over_outlined,
      title: '拜訪紀錄（${records.length}）',
      action: TextButton(
        onPressed: () => context.go(AppRoutes.visitRecords),
        child: const Text('前往拜訪紀錄'),
      ),
      child: records.isEmpty
          ? const CustomerDetailEmptyText('還沒有連結這位客戶的拜訪紀錄。可在拜訪紀錄單篇頁的「連結客戶」選擇這位客戶')
          : Column(children: items),
    );
  }
}

/// 保額文字：1000000 → 「1,000,000」
String formatCoverageAmount(int amount) => NumberFormat('#,###').format(amount);

