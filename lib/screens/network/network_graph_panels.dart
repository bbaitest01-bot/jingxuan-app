import 'package:flutter/material.dart';

import '../../services/customer_card_summary_service.dart';
import '../../services/network_graph_layout.dart';
import '../../theme/app_theme.dart';
import '../topology_colors.dart';

/// 關係類型（篩選按鈕的順序與文字）
const List<(String, String)> networkRelationshipTypes = [
  ('referral', '轉介紹'),
  ('family', '親眷'),
  ('workplace', '職場'),
  ('social', '社團'),
  ('other', '其他'),
];

/// 人脈圖上方的工具列：找人、關係類型篩選（同時是圖例）、沒有關係的客戶、置中、重新讀取
class NetworkGraphToolbar extends StatelessWidget {
  final Set<String> hiddenTypes;
  final ValueChanged<String> onToggleType;
  final bool hideLoneNodes;
  final int loneNodeCount;
  final VoidCallback onToggleLone;
  final ValueChanged<String> onSearch;
  final VoidCallback onFit;
  final VoidCallback onRefresh;

  const NetworkGraphToolbar({
    super.key,
    required this.hiddenTypes,
    required this.onToggleType,
    required this.hideLoneNodes,
    required this.loneNodeCount,
    required this.onToggleLone,
    required this.onSearch,
    required this.onFit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> chips = [];
    for (final (String type, String label) in networkRelationshipTypes) {
      chips.add(_FilterChip(
        label: label,
        lineColor: topologyEdgeColor(context, type),
        isOn: !hiddenTypes.contains(type),
        onTap: () => onToggleType(type),
      ));
    }
    chips.add(_FilterChip(
      label: '沒有關係的客戶（$loneNodeCount）',
      dotColor: colors.ink3,
      isOn: !hideLoneNodes,
      onTap: onToggleLone,
    ));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          height: 36,
          child: TextField(
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: '找人：輸入名字',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        ...chips,
        IconButton(onPressed: onFit, icon: const Icon(Icons.center_focus_strong_rounded), tooltip: '縮放到全部看得到'),
        IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), tooltip: '重新讀取'),
      ],
    );
  }
}

/// 可以開關的篩選按鈕；關掉時變淡
class _FilterChip extends StatelessWidget {
  final String label;
  final Color? lineColor;
  final Color? dotColor;
  final bool isOn;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isOn, required this.onTap, this.lineColor, this.dotColor});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Widget marker = Container(width: 14, height: 3, color: lineColor);
    final Color? dot = dotColor;
    if (dot != null) {
      marker = Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle));
    }
    double opacity = 0.4;
    if (isOn) opacity = 1;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              marker,
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: colors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 點一下圓點後出現的資訊卡：階段、由誰介紹、介紹了誰、有幾位認識的人
class NetworkNodeInfoCard extends StatelessWidget {
  final NetworkGraph graph;
  final NetworkGraphNode node;
  final VoidCallback onOpenCustomer;
  final VoidCallback onManageRelationships;
  final VoidCallback onClose;

  const NetworkNodeInfoCard({
    super.key,
    required this.graph,
    required this.node,
    required this.onOpenCustomer,
    required this.onManageRelationships,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> referrerNames = [];
    final List<String> referredNames = [];
    for (final NetworkGraphEdge edge in graph.edges) {
      if (edge.type != 'referral') continue;
      if (edge.to.id == node.id) referrerNames.add(edge.from.name);
      if (edge.from.id == node.id) referredNames.add(edge.to.name);
    }
    final int knownCount = graph.neighborIdsOf(node.id).length - 1;
    final String stageText = CustomerCardSummaryService.instance.summaryOf(node.id).policyText;

    final List<Widget> lines = [_InfoLine(icon: Icons.verified_user_outlined, text: stageText)];
    if (referrerNames.isNotEmpty) {
      lines.add(_InfoLine(icon: Icons.call_received_rounded, text: '由 ${referrerNames.join('、')} 介紹'));
    }
    if (referredNames.isNotEmpty) {
      lines.add(_InfoLine(icon: Icons.call_made_rounded, text: '介紹了 ${referredNames.join('、')}'));
    }
    String knownText = '還沒有建立關係';
    if (knownCount > 0) knownText = '直接認識 $knownCount 位';
    lines.add(_InfoLine(icon: Icons.hub_outlined, text: knownText));

    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 客戶名字常有罕見字，宋體沒收錄會混到別的字型，所以用黑體（2026-10-30 沛沛反映「陳又瑄」字體不一樣）
              Expanded(
                child: Text(node.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.ink)),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: '關閉',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          ...lines,
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(onPressed: onOpenCustomer, child: const Text('打開客戶')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onManageRelationships, child: const Text('管理關係')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final Color color = context.appColors.ink2;
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}
