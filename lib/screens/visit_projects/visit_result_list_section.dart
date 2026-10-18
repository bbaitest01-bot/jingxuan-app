import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/visit_project.dart';
import '../../models/visit_result.dart';
import '../../router/app_routes.dart';
import '../../services/customer_service.dart';
import '../customers/customer_status_widgets.dart';
import 'visit_pending_section.dart';

/// 專案拜訪頁下方的「拜訪結果紀錄」：新的在上面，可依專案篩選，每筆可修改（P3、P5）
class VisitResultListSection extends StatelessWidget {
  final List<VisitResult> results;
  final List<VisitProject> projects;
  final String? filterProjectId;
  final bool hasMore;
  final DateTime today;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<VisitResult> onEdit;
  final VoidCallback onShowMore;

  const VisitResultListSection({
    super.key,
    required this.results,
    required this.projects,
    required this.filterProjectId,
    required this.hasMore,
    required this.today,
    required this.onFilterChanged,
    required this.onEdit,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    for (final VisitResult result in results) {
      rows.add(_VisitResultRow(result: result, today: today, onEdit: () => onEdit(result)));
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 外層給滿寬，兩端對齊才會生效（標題在左、篩選在右）
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('拜訪結果紀錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _ProjectFilter(projects: projects, value: filterProjectId, onChanged: onFilterChanged),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '記錯了按「修改」，可以改專案、客戶、日期、結果，或刪除。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('還沒有拜訪結果。拜訪完按「記錄拜訪」記下 ✔ △ ✖。'),
              ),
            ...rows,
            if (hasMore)
              Center(child: TextButton(onPressed: onShowMore, child: const Text('顯示更多'))),
          ],
        ),
      ),
    );
  }
}

class _ProjectFilter extends StatelessWidget {
  final List<VisitProject> projects;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ProjectFilter({required this.projects, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String?>> items = [const DropdownMenuItem<String?>(value: null, child: Text('全部專案'))];
    for (final VisitProject project in projects) {
      items.add(DropdownMenuItem<String?>(value: project.id, child: Text(project.title, overflow: TextOverflow.ellipsis)));
    }
    return DropdownButton<String?>(value: value, items: items, onChanged: onChanged);
  }
}

class _VisitResultRow extends StatelessWidget {
  final VisitResult result;
  final DateTime today;
  final VoidCallback onEdit;

  const _VisitResultRow({required this.result, required this.today, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final Color mutedColor = Theme.of(context).hintColor;
    final String symbol = CustomerService.clientStatusSymbol(result.result);
    final List<String> details = [result.projectTitle];
    if (result.note.isNotEmpty) details.add(result.note);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(friendlyEventDate(result.visitedOn, today), style: TextStyle(fontSize: 13, color: mutedColor)),
          ),
          SizedBox(
            width: 24,
            child: Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(context, result.result))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(details.join('・'), style: TextStyle(fontSize: 13, color: mutedColor)),
                if (result.hasVisitRecord) _VisitRecordLink(result: result),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('修改')),
        ],
      ),
    );
  }
}

/// 連結的拜訪紀錄：只顯示標題，點了打開那一篇；紀錄已刪除就顯示提示，不能點（P5）
class _VisitRecordLink extends StatelessWidget {
  final VisitResult result;

  const _VisitRecordLink({required this.result});

  @override
  Widget build(BuildContext context) {
    final String? recordId = result.visitRecordId;
    if (recordId == null) return const SizedBox.shrink();
    if (result.isVisitRecordDeleted) {
      return Text('🔗 此紀錄已刪除', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor));
    }
    String title = result.visitRecordTitle;
    if (title.isEmpty) title = '拜訪紀錄';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(AppRoutes.visitRecordPath(recordId)),
      child: Text(
        '🔗 $title',
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
      ),
    );
  }
}
