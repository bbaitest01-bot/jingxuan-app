import 'package:flutter/material.dart';

import '../../services/customer_card_summary_service.dart';
import '../../services/customer_stage_service.dart';
import '../../services/network_graph_layout.dart';
import '../../theme/app_theme.dart';

/// 人脈圖左上角的搜尋結果清單（2026-11-01 沛沛：打「王」要看到所有姓王的人，不是只選第一個）
///
/// 列出名字裡有輸入字的人和他的客戶階段；點名字才選取那個人、移到中間、看他的關係。
class NetworkSearchResults extends StatelessWidget {
  final String keyword;
  final List<NetworkGraphNode> matches;
  final ValueChanged<NetworkGraphNode> onSelect;

  const NetworkSearchResults({super.key, required this.keyword, required this.matches, required this.onSelect});

  /// 清單最多顯示幾位，再多就要捲動
  static const double _maxListHeight = 260;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String title = '找到 ${matches.length} 位「$keyword」';
    if (matches.isEmpty) title = '找不到名字有「$keyword」的人';
    final List<Widget> rows = [];
    for (final NetworkGraphNode node in matches) {
      rows.add(_SearchResultRow(node: node, onTap: () => onSelect(node)));
    }
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink)),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxListHeight),
              child: SingleChildScrollView(child: Column(children: rows)),
            ),
            const SizedBox(height: 6),
            Text('點名字：移到中間、看他的關係', style: TextStyle(fontSize: 11, color: colors.ink3)),
          ],
        ],
      ),
    );
  }
}

/// 清單的一列：名字＋客戶階段
class _SearchResultRow extends StatelessWidget {
  final NetworkGraphNode node;
  final VoidCallback onTap;

  const _SearchResultRow({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final CustomerCardSummary summary = CustomerCardSummaryService.instance.summaryOf(node.id);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(fontSize: 14, color: colors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(CustomerStage.label(summary.stage), style: TextStyle(fontSize: 12, color: colors.ink3)),
            ],
          ),
        ),
      ),
    );
  }
}
