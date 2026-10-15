import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../models/visit_result.dart';
import '../../services/customer_service.dart';
import '../../services/visit_result_service.dart';
import '../../widgets/custom_toast.dart';
import '../customers/customer_status_widgets.dart';
import 'visit_pending_section.dart';
import 'visit_result_form_dialog.dart';

/// 專案卡片的「看名單與紀錄」（照模型補上）：
/// 名單裡每個人這一期拜訪過沒（沒拜訪的可以直接記錄），以及這一期的拜訪結果（可修改）。
/// 視窗裡有記錄或修改過就回傳 true，讓頁面重讀
Future<bool> showVisitProjectDetailDialog(
  BuildContext context, {
  required VisitProject project,
  required List<VisitProject> allProjects,
}) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _VisitProjectDetailDialog(project: project, allProjects: allProjects),
  );
  return changed == true;
}

class _VisitProjectDetailDialog extends StatefulWidget {
  final VisitProject project;
  final List<VisitProject> allProjects;

  const _VisitProjectDetailDialog({required this.project, required this.allProjects});

  @override
  State<_VisitProjectDetailDialog> createState() => _VisitProjectDetailDialogState();
}

class _VisitProjectDetailDialogState extends State<_VisitProjectDetailDialog> {
  List<VisitResult> _periodResults = [];
  bool _isLoading = true;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  // 讀這個專案的結果，只留「這一期」的（新的在前）
  Future<void> _loadResults() async {
    final ({DateTime start, DateTime end}) period = widget.project.currentPeriod(DateTime.now());
    try {
      final List<VisitResult> all = await VisitResultService.instance.fetchMyResults(projectId: widget.project.id, limit: 500);
      final List<VisitResult> inPeriod = [];
      for (final VisitResult result in all) {
        if (result.visitedOn.isBefore(period.start) || result.visitedOn.isAfter(period.end)) continue;
        inPeriod.add(result);
      }
      if (!mounted) return;
      setState(() {
        _periodResults = inPeriod;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, '讀取紀錄失敗：$e', ToastType.error);
    }
  }

  Future<void> _recordMember(String customerId, String customerName) async {
    final bool saved = await showVisitResultFormDialog(
      context,
      projects: widget.allProjects,
      initialProjectId: widget.project.id,
      preset: VisitResultPreset(customerId: customerId, customerName: customerName, visitedOn: DateTime.now()),
    );
    if (!saved || !mounted) return;
    _hasChanged = true;
    await _loadResults();
  }

  Future<void> _editResult(VisitResult result) async {
    final bool saved = await showVisitResultFormDialog(context, projects: widget.allProjects, result: result);
    if (!saved || !mounted) return;
    _hasChanged = true;
    await _loadResults();
  }

  @override
  Widget build(BuildContext context) {
    final VisitProject project = widget.project;
    final DateTime today = DateTime.now();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(project.title),
      content: SizedBox(
        width: 480,
        child: _isLoading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${project.periodText(today)}・目標 ${project.targetCount} 次・這一期 ${_periodResults.length} 次',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 16),
                    const Text('名單', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._buildMemberRows(),
                    const SizedBox(height: 16),
                    const Text('這一期的拜訪', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._buildResultRows(today),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _hasChanged), child: const Text('關閉')),
      ],
    );
  }

  // 名單每個人一列：拜訪過顯示最新結果與次數；沒拜訪過顯示「記錄」按鈕
  List<Widget> _buildMemberRows() {
    final VisitProject project = widget.project;
    if (!project.hasMembers) {
      return [_hintText('這個專案沒有名單，任何客戶的拜訪都算進度。')];
    }
    final List<Widget> rows = [];
    for (final MapEntry<String, String> member in project.members.entries) {
      final List<VisitResult> mine = _periodResults.where((result) => result.customerId == member.key).toList();
      Widget trailing;
      if (mine.isEmpty) {
        trailing = OutlinedButton(
          onPressed: () => _recordMember(member.key, member.value),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('還沒拜訪・記錄'),
        );
      } else {
        final VisitResult latest = mine.first;
        trailing = Text.rich(TextSpan(children: [
          TextSpan(
            text: CustomerService.clientStatusSymbol(latest.result),
            style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(latest.result)),
          ),
          TextSpan(
            text: '  ${VisitProject.formatMonthDay(latest.visitedOn)}・${mine.length} 次',
            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
          ),
        ]));
      }
      rows.add(_DetailRow(leading: Text(member.value, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: trailing));
    }
    return rows;
  }

  List<Widget> _buildResultRows(DateTime today) {
    if (_periodResults.isEmpty) return [_hintText('這一期還沒有拜訪。')];
    final List<Widget> rows = [];
    for (final VisitResult result in _periodResults) {
      final String symbol = CustomerService.clientStatusSymbol(result.result);
      final String note = result.note.isEmpty ? '' : '  ${result.note}';
      rows.add(_DetailRow(
        leading: Text.rich(TextSpan(children: [
          TextSpan(text: '${friendlyEventDate(result.visitedOn, today)}  ', style: TextStyle(color: Theme.of(context).hintColor)),
          TextSpan(text: '$symbol ', style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(result.result))),
          TextSpan(text: result.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: note, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
        ])),
        trailing: TextButton(onPressed: () => _editResult(result), child: const Text('修改')),
      ));
    }
    return rows;
  }

  Widget _hintText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
    );
  }
}

/// 一列：左邊內容、右邊按鈕或狀態
class _DetailRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;

  const _DetailRow({required this.leading, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(child: leading),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
