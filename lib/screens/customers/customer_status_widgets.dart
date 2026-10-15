import 'package:flutter/material.dart';
import '../../models/visit_result.dart';
import '../../services/customer_service.dart';
import '../../services/visit_result_service.dart';

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

/// 客戶狀態＋來源（4-2b 起狀態由專案拜訪結果自動帶入，客戶管理只顯示）
/// 例：「✔ 有意願／已成交（日常拜訪，10/14）」；沒有拜訪結果時說明怎麼帶入
class CustomerStatusSourceText extends StatefulWidget {
  final String customerId;
  final String? status;

  const CustomerStatusSourceText({super.key, required this.customerId, required this.status});

  @override
  State<CustomerStatusSourceText> createState() => _CustomerStatusSourceTextState();
}

class _CustomerStatusSourceTextState extends State<CustomerStatusSourceText> {
  ClientStatusSource? _source;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant CustomerStatusSourceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool changed = oldWidget.customerId != widget.customerId || oldWidget.status != widget.status;
    if (changed) _loadSource();
  }

  Future<void> _loadSource() async {
    if (widget.customerId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final ClientStatusSource? source = await VisitResultService.instance.fetchStatusSource(widget.customerId);
      if (!mounted) return;
      setState(() {
        _source = source;
        _isLoading = false;
      });
    } catch (_) {
      // 讀不到來源時只顯示狀態本身，不影響其他資料
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? status = widget.status;
    final String symbol = CustomerService.clientStatusSymbol(status);
    final String label = CustomerService.clientStatusLabel(status);
    String statusText = label;
    if (symbol.isNotEmpty) statusText = '$symbol $label';

    String sourceText = '';
    final ClientStatusSource? source = _source;
    if (_isLoading) {
      sourceText = '';
    } else if (source != null) {
      sourceText = '（${source.projectTitle}，${source.visitedOn.month}/${source.visitedOn.day}）';
    } else if (symbol.isNotEmpty) {
      sourceText = '（之前手動設定，記錄拜訪後會自動更新）';
    } else {
      sourceText = '（記錄拜訪後自動帶入）';
    }

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: statusText, style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(status))),
        TextSpan(text: sourceText, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}
