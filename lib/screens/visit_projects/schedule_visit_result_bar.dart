import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../models/visit_result.dart';
import '../../services/customer_service.dart';
import '../../services/visit_pending_service.dart';
import '../../services/visit_project_service.dart';
import '../../services/visit_result_service.dart';
import '../../widgets/custom_toast.dart';
import '../customers/customer_status_widgets.dart';
import 'visit_result_form_dialog.dart';

/// 今日行程的行程視窗最上面的「拜訪結果」列（4-2c）。
/// 只有「有客戶、時間已到」的行程才出現：還沒記錄 → 記錄結果／沒拜訪；已記錄 → 結果＋修改；沒拜訪 → 復原
class ScheduleVisitResultBar extends StatefulWidget {
  final String eventId;

  const ScheduleVisitResultBar({super.key, required this.eventId});

  @override
  State<ScheduleVisitResultBar> createState() => _ScheduleVisitResultBarState();
}

class _ScheduleVisitResultBarState extends State<ScheduleVisitResultBar> {
  PendingVisitEvent? _event;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.eventId.isEmpty) return;
    try {
      final PendingVisitEvent? event = await VisitPendingService.instance.fetchEventStatus(widget.eventId, DateTime.now());
      if (!mounted) return;
      setState(() => _event = event);
    } catch (_) {
      // 讀不到就不顯示這一列，不影響編輯行程
    }
  }

  Future<void> _record(PendingVisitEvent event) async {
    setState(() => _isBusy = true);
    try {
      final List<VisitProject> projects = await VisitProjectService.instance.fetchMyProjects();
      if (!mounted) return;
      final bool saved = await showVisitResultFormDialog(
        context,
        projects: projects,
        preset: VisitResultPreset(
          customerId: event.customerId,
          customerName: event.customerName,
          visitedOn: event.startAt,
          scheduleEventId: event.eventId,
          eventTitle: event.title,
        ),
      );
      if (saved && mounted) CustomToast.show(context, '已記錄 ${event.customerName} 的拜訪結果', ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '讀取專案失敗：$e', ToastType.error);
    }
    await _finish();
  }

  Future<void> _edit(PendingVisitEvent event) async {
    final String? resultId = event.resultId;
    if (resultId == null) return;
    setState(() => _isBusy = true);
    try {
      final VisitResult? result = await VisitResultService.instance.fetchResult(resultId);
      final List<VisitProject> projects = await VisitProjectService.instance.fetchMyProjects();
      if (!mounted) return;
      if (result != null) {
        await showVisitResultFormDialog(context, projects: projects, result: result);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, '讀取結果失敗：$e', ToastType.error);
    }
    await _finish();
  }

  Future<void> _setSkipped(PendingVisitEvent event, bool isSkipped) async {
    setState(() => _isBusy = true);
    try {
      if (isSkipped) {
        await VisitPendingService.instance.markSkipped(event.eventId);
      } else {
        await VisitPendingService.instance.undoSkipped(event.eventId);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, '更新失敗：$e', ToastType.error);
    }
    await _finish();
  }

  Future<void> _finish() async {
    await _load();
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final PendingVisitEvent? event = _event;
    if (event == null) return const SizedBox.shrink();
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildStatusText(event),
          Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: _buildActions(event)),
        ],
      ),
    );
  }

  Widget _buildStatusText(PendingVisitEvent event) {
    if (event.isRecorded) {
      final String status = event.result ?? '';
      final String text = '拜訪結果：${CustomerService.clientStatusSymbol(status)} ${CustomerService.clientStatusLabel(status)}';
      return Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(context, status)));
    }
    if (event.isSkipped) return const Text('這次標記為「沒拜訪」（不算進度）');
    return Text('這次拜訪 ${event.customerName} 還沒記錄結果', style: const TextStyle(fontWeight: FontWeight.bold));
  }

  List<Widget> _buildActions(PendingVisitEvent event) {
    if (_isBusy) {
      return const [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))];
    }
    if (event.isRecorded) {
      return [TextButton(onPressed: () => _edit(event), child: const Text('修改'))];
    }
    if (event.isSkipped) {
      return [TextButton(onPressed: () => _setSkipped(event, false), child: const Text('復原'))];
    }
    return [
      TextButton(onPressed: () => _setSkipped(event, true), child: const Text('沒拜訪')),
      FilledButton(
        onPressed: () => _record(event),
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('記錄結果'),
      ),
    ];
  }
}
