import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/visit_result.dart';
import '../../services/customer_service.dart';
import '../../services/visit_result_service.dart';

/// 「△ 考慮中」專用的亮橘色（2026-10-18 沛沛選定：主題的提醒色偏咖啡，要橘一點）。
/// 亮橘當純文字在米白底上偏淡，所以小標記膠囊裡改用深一點的橘字＋淡橘底
class CustomerConsideringColors {
  static const Color light = Color(0xFFD97706);
  static const Color lightBadgeText = Color(0xFFB05E00);
  static const Color lightBadgeBackground = Color(0xFFFDEBD0);
  static const Color dark = Color(0xFFF0B54A);
  static const Color darkBadgeBackground = Color(0xFF3A2A12);
}

/// 客戶狀態的顏色：✔ 綠、△ 亮橘、✖ 紅（4-3c）；綠、紅用主題的成功／危險色，明亮深色各自調過
Color customerStatusColor(BuildContext context, String? status) {
  final AppColors colors = context.appColors;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  if (status == CustomerService.statusPositive) return colors.ok;
  if (status == CustomerService.statusConsidering) {
    if (isDark) return CustomerConsideringColors.dark;
    return CustomerConsideringColors.light;
  }
  if (status == CustomerService.statusNegative) return Theme.of(context).colorScheme.error;
  return colors.ink3;
}

/// 客戶卡片、整頁標題旁的小標記（例：「✔ 有意願」）；未設定就不顯示
class CustomerStatusBadge extends StatelessWidget {
  final String? status;

  const CustomerStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final String symbol = CustomerService.clientStatusSymbol(status);
    if (symbol.isEmpty) return const SizedBox.shrink();
    final Color color = customerStatusColor(context, status);
    // 卡片空間小，只顯示說明的前半段（有意願／考慮中／無意願）
    final String shortLabel = CustomerService.clientStatusLabel(status).split('／').first;

    // 一般狀態：淡同色底＋同色字；考慮中：淡橘底＋深一點的橘字，亮橘字才讀得清楚
    Color textColor = color;
    Color backgroundColor = color.withValues(alpha: 0.12);
    if (status == CustomerService.statusConsidering) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        backgroundColor = CustomerConsideringColors.darkBadgeBackground;
      } else {
        textColor = CustomerConsideringColors.lightBadgeText;
        backgroundColor = CustomerConsideringColors.lightBadgeBackground;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$symbol $shortLabel',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
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
        TextSpan(text: statusText, style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(context, status))),
        TextSpan(text: sourceText, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}
