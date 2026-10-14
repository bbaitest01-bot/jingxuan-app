import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/visit_record.dart';
import '../../../router/app_routes.dart';
import '../../../services/customer_policy_service.dart';
import '../../visit_records/visit_record_widgets.dart';

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
    final Color primaryColor = Theme.of(context).colorScheme.primary;
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
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
          const Text('標籤', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          if (tags.isEmpty) const CustomerDetailEmptyText('沒有標籤'),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList(),
            ),
          const SizedBox(height: 12),
          const Text('備註', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          if (notes.trim().isEmpty) const CustomerDetailEmptyText('沒有備註'),
          if (notes.trim().isNotEmpty) SelectableText(notes, style: const TextStyle(fontSize: 14, height: 1.6)),
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
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: SelectableText(displayValue, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// 保單：目前先照原本的資料顯示；「現有／舊保單」分組在 4-3d（C6）
class CustomerPoliciesSection extends StatelessWidget {
  final List<CustomerEnrolledPolicy> policies;

  const CustomerPoliciesSection({super.key, required this.policies});

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];
    for (final CustomerEnrolledPolicy policy in policies) {
      items.add(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined),
        title: Text(policy.productName),
        subtitle: Text('${policy.companyName} · ${policy.category} · 加入於 ${formatVisitRecordTime(policy.enrolledAt)}'),
      ));
    }

    return CustomerDetailSection(
      icon: Icons.health_and_safety_outlined,
      title: '保單（${policies.length}）',
      child: policies.isEmpty
          ? const CustomerDetailEmptyText('還沒有保單，可在「快速預覽」的「保單健檢與缺口」加入')
          : Column(children: items),
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
