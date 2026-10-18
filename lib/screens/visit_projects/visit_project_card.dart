import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../services/customer_service.dart';
import '../customers/customer_status_widgets.dart';
import '../../theme/app_theme.dart';

/// 專案代表色（2026-10-18 沛沛選定）：從「鮮明組」擴充成 8 色，依專案在清單裡的順序輪流用。
/// 原本 5 色不夠（第 6 個專案又變回藍色），而且「藍紫」跟藍太像，所以拿掉藍紫、加草綠與金黃；
/// 順序讓相鄰的專案色相差最多，紫色與藍灰排在第 7、8 個。不跟主題色變、不用純灰（「總數」線是灰色）
class VisitProjectPalette {
  static const List<Color> light = [
    Color(0xFF1E7FD8), // 藍
    Color(0xFFE07B12), // 橘
    Color(0xFF159A7A), // 青綠
    Color(0xFFD14B6E), // 玫瑰紅
    Color(0xFF5A9E2F), // 草綠
    Color(0xFFC99400), // 金黃
    Color(0xFF8E5CC9), // 紫
    Color(0xFF6B7A99), // 藍灰
  ];
  static const List<Color> dark = [
    Color(0xFF6BB0F0),
    Color(0xFFF2A65A),
    Color(0xFF4FCAA8),
    Color(0xFFE8869F),
    Color(0xFF8CCB5E),
    Color(0xFFE8C04A),
    Color(0xFFB693E6),
    Color(0xFF9DABC8),
  ];
}

Color visitProjectColor(BuildContext context, int index) {
  List<Color> palette = VisitProjectPalette.light;
  if (Theme.of(context).brightness == Brightness.dark) {
    palette = VisitProjectPalette.dark;
  }
  return palette[index % palette.length];
}

/// 專案卡片：名稱、期間、這一期進度、✔△✖ 次數、名單還有誰沒拜訪
class VisitProjectCard extends StatelessWidget {
  final VisitProject project;
  final VisitProjectProgress progress;
  final DateTime today;
  // 卡片色點（跟圖表的線同色）
  final Color color;
  final VoidCallback onRecord;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VisitProjectCard({
    super.key,
    required this.project,
    required this.progress,
    required this.today,
    required this.color,
    required this.onRecord,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color mutedColor = Theme.of(context).hintColor;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectTitleRow(project: project, color: color),
            const SizedBox(height: 4),
            Text(project.periodText(today), style: TextStyle(fontSize: 13, color: mutedColor)),
            if (project.purpose.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(project.purpose, style: TextStyle(fontSize: 13, color: mutedColor), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            _ProgressBlock(project: project, progress: progress, color: primaryColor),
            const SizedBox(height: 10),
            _ResultCounts(progress: progress),
            const SizedBox(height: 8),
            _MemberLine(project: project, progress: progress),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('記錄拜訪'),
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('看名單與紀錄'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                if (!project.isDefault)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                    label: Text('刪除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTitleRow extends StatelessWidget {
  final VisitProject project;
  final Color color;

  const _ProjectTitleRow({required this.project, required this.color});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            project.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (project.isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('預設', style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final VisitProject project;
  final VisitProjectProgress progress;
  final Color color;

  const _ProgressBlock({required this.project, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('這一期進度', style: TextStyle(fontSize: 13))),
            Text(
              '${progress.visitCount} / ${project.targetCount} 次',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress.ratioOf(project.targetCount),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _ResultCounts extends StatelessWidget {
  final VisitProjectProgress progress;

  const _ResultCounts({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      children: [
        _countText(context, CustomerService.statusPositive, progress.positiveCount),
        _countText(context, CustomerService.statusConsidering, progress.consideringCount),
        _countText(context, CustomerService.statusNegative, progress.negativeCount),
      ],
    );
  }

  Widget _countText(BuildContext context, String status, int count) {
    final String symbol = CustomerService.clientStatusSymbol(status);
    return Text(
      '$symbol $count',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: customerStatusColor(context, status)),
    );
  }
}

class _MemberLine extends StatelessWidget {
  final VisitProject project;
  final VisitProjectProgress progress;

  const _MemberLine({required this.project, required this.progress});

  @override
  Widget build(BuildContext context) {
    final Color mutedColor = Theme.of(context).hintColor;
    if (!project.hasMembers) {
      return Text('沒有名單，任何客戶都算', style: TextStyle(fontSize: 13, color: mutedColor));
    }

    final int memberCount = project.members.length;
    final List<String> unvisited = progress.unvisitedMemberNames;
    if (unvisited.isEmpty) {
      return Text('名單 $memberCount 人都拜訪過了', style: TextStyle(fontSize: 13, color: context.appColors.ok));
    }
    // 名字太多只列前 5 位
    final String names = unvisited.take(5).join('、');
    final String more = unvisited.length > 5 ? ' 等' : '';
    return Text(
      '名單 $memberCount 人，還有 ${unvisited.length} 人沒拜訪：$names$more',
      style: TextStyle(fontSize: 13, color: context.appColors.warn),
    );
  }
}
