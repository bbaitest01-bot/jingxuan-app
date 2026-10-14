import 'package:flutter/material.dart';
import '../../services/customer_service.dart';

/// 客戶狀態的顏色：✔ 綠、△ 橘、✖ 紅（4-3c）
Color customerStatusColor(String? status) {
  if (status == CustomerService.statusPositive) return Colors.green;
  if (status == CustomerService.statusConsidering) return Colors.orange;
  if (status == CustomerService.statusNegative) return Colors.redAccent;
  return Colors.grey;
}

/// 客戶卡片、整頁標題旁的小標記（例：「✔ 有意願」）；未設定就不顯示
class CustomerStatusBadge extends StatelessWidget {
  final String? status;

  const CustomerStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final String symbol = CustomerService.clientStatusSymbol(status);
    if (symbol.isEmpty) return const SizedBox.shrink();
    final Color color = customerStatusColor(status);
    // 卡片空間小，只顯示說明的前半段（有意願／考慮中／無意願）
    final String shortLabel = CustomerService.clientStatusLabel(status).split('／').first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$symbol $shortLabel',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// 名字＋狀態小標記排在同一行（名字太長會截斷，標記保持完整）
class CustomerNameWithStatus extends StatelessWidget {
  final String name;
  final String? status;
  final TextStyle style;

  const CustomerNameWithStatus({super.key, required this.name, required this.status, required this.style});

  @override
  Widget build(BuildContext context) {
    final bool hasStatus = CustomerService.clientStatusSymbol(status).isNotEmpty;
    return Row(
      children: [
        Flexible(child: Text(name, style: style, overflow: TextOverflow.ellipsis)),
        if (hasStatus) const SizedBox(width: 6),
        if (hasStatus) CustomerStatusBadge(status: status),
      ],
    );
  }
}

/// 客戶狀態選擇：✔ 有意願／△ 考慮中／✖ 無意願／未設定（表單與抽屜共用）
class CustomerStatusSelector extends StatelessWidget {
  final String? status;
  final ValueChanged<String?> onChanged;

  const CustomerStatusSelector({super.key, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Icon(Icons.flag_outlined, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('客戶狀態', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: CustomerService.clientStatusOptions.map((String? option) {
              final String symbol = CustomerService.clientStatusSymbol(option);
              final String label = CustomerService.clientStatusLabel(option).split('／').first;
              return ChoiceChip(
                label: Text(symbol.isEmpty ? label : '$symbol $label'),
                selected: status == option,
                onSelected: (_) => onChanged(option),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
