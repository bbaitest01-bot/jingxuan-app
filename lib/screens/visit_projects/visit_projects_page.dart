import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../models/visit_result.dart';
import '../../services/visit_pending_service.dart';
import '../../services/visit_project_service.dart';
import '../../services/visit_result_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_pending_section.dart';
import 'visit_project_card.dart';
import 'visit_project_form_dialog.dart';
import 'visit_result_form_dialog.dart';
import 'visit_result_list_section.dart';

/// 卡片排兩欄的最小寬度
const double visitProjectTwoColumnWidth = 720;

/// 拜訪結果紀錄一次顯示幾筆，按「顯示更多」再多這麼多
const int visitResultPageSize = 20;

/// 專案拜訪頁（/projects）：我的專案卡片、建立／編輯／刪除專案（4-2a）；
/// 記錄拜訪與拜訪結果紀錄（4-2b）；還沒記錄結果的行程（4-2c）。成效圖表（4-2d）之後加在這頁。
class VisitProjectsPage extends StatefulWidget {
  const VisitProjectsPage({super.key});

  @override
  State<VisitProjectsPage> createState() => _VisitProjectsPageState();
}

class _VisitProjectsPageState extends State<VisitProjectsPage> {
  List<VisitProject> _projects = [];
  List<VisitResultSummary> _results = [];
  // 拜訪結果紀錄（下方列表）
  List<VisitResult> _resultRecords = [];
  // 還沒記錄結果的行程（上方清單）
  PendingVisitLists _pendingLists = const PendingVisitLists(pending: [], recentlyDone: []);
  String? _filterProjectId;
  int _resultLimit = visitResultPageSize;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  // 先讀專案，再讀「各專案這一期」範圍內的拜訪結果來算進度
  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<VisitProject> projects = await VisitProjectService.instance.fetchMyProjects();
      final DateTime fromDate = VisitProjectService.earliestPeriodStart(projects, DateTime.now());
      final List<VisitResultSummary> results = await VisitProjectService.instance.fetchResultsSince(fromDate);
      // 多讀一筆，才知道還有沒有「顯示更多」
      final List<VisitResult> resultRecords = await VisitResultService.instance.fetchMyResults(
        projectId: _filterProjectId,
        limit: _resultLimit + 1,
      );
      final PendingVisitLists pendingLists = await VisitPendingService.instance.fetchLists(DateTime.now());
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _results = results;
        _resultRecords = resultRecords;
        _pendingLists = pendingLists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取專案失敗：$e';
        _isLoading = false;
      });
    }
  }

  // 記錄拜訪：從卡片進來時預設那個專案，從上方按鈕進來預設日常拜訪
  Future<void> _openRecord({String? projectId}) async {
    final bool saved = await showVisitResultFormDialog(context, projects: _projects, initialProjectId: projectId);
    if (!saved || !mounted) return;
    CustomToast.show(context, '已記錄拜訪，客戶狀態已更新', ToastType.success);
    await _loadProjects();
  }

  Future<void> _openEditResult(VisitResult result) async {
    final bool saved = await showVisitResultFormDialog(context, projects: _projects, result: result);
    if (!saved || !mounted) return;
    CustomToast.show(context, '已更新拜訪結果', ToastType.success);
    await _loadProjects();
  }

  // 從待記錄的行程記錄結果：客戶與日期帶好，專案預設日常拜訪，並記住是哪個行程
  Future<void> _recordFromEvent(PendingVisitEvent event) async {
    final bool saved = await showVisitResultFormDialog(
      context,
      projects: _projects,
      preset: VisitResultPreset(
        customerId: event.customerId,
        customerName: event.customerName,
        visitedOn: event.startAt,
        scheduleEventId: event.eventId,
        eventTitle: event.title,
      ),
    );
    if (!saved || !mounted) return;
    CustomToast.show(context, '已記錄 ${event.customerName} 的拜訪結果', ToastType.success);
    await _loadProjects();
  }

  Future<void> _editEventResult(PendingVisitEvent event) async {
    final String? resultId = event.resultId;
    if (resultId == null) return;
    try {
      final VisitResult? result = await VisitResultService.instance.fetchResult(resultId);
      if (!mounted) return;
      if (result == null) {
        CustomToast.show(context, '找不到這筆結果，可能已被刪除', ToastType.warning);
        await _loadProjects();
        return;
      }
      await _openEditResult(result);
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '讀取結果失敗：$e', ToastType.error);
    }
  }

  // 「沒拜訪」與「復原」：成功後重讀清單
  Future<void> _setSkipped(PendingVisitEvent event, bool isSkipped) async {
    try {
      if (isSkipped) {
        await VisitPendingService.instance.markSkipped(event.eventId);
      } else {
        await VisitPendingService.instance.undoSkipped(event.eventId);
      }
      if (!mounted) return;
      final String message = isSkipped ? '已標記「沒拜訪」：${event.customerName}，不算進度' : '已復原，回到還沒記錄結果';
      CustomToast.show(context, message, ToastType.success);
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '更新失敗：$e', ToastType.error);
    }
  }

  void _changeFilter(String? projectId) {
    setState(() {
      _filterProjectId = projectId;
      _resultLimit = visitResultPageSize;
    });
    _loadProjects();
  }

  void _showMoreResults() {
    setState(() => _resultLimit += visitResultPageSize);
    _loadProjects();
  }

  Future<void> _openCreate() async {
    final bool saved = await showVisitProjectFormDialog(context);
    if (!saved || !mounted) return;
    CustomToast.show(context, '已建立專案', ToastType.success);
    await _loadProjects();
  }

  Future<void> _openEdit(VisitProject project) async {
    final bool saved = await showVisitProjectFormDialog(context, project: project);
    if (!saved || !mounted) return;
    CustomToast.show(context, '已更新「${project.title}」', ToastType.success);
    await _loadProjects();
  }

  // 刪除前先說明會一起刪掉幾筆拜訪結果（P6）
  Future<void> _confirmDelete(VisitProject project) async {
    int resultCount = 0;
    try {
      resultCount = await VisitProjectService.instance.countResults(project.id);
    } catch (_) {
      // 數不出來也讓使用者決定，只是提示文字不寫數字
      resultCount = -1;
    }
    if (!mounted) return;

    String resultText = '專案裡的拜訪結果會一起刪除。';
    if (resultCount >= 0) resultText = '專案裡的 $resultCount 筆拜訪結果會一起刪除。';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('刪除「${project.title}」？'),
        content: Text('$resultText\n連結的拜訪紀錄不受影響。刪除後無法還原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await VisitProjectService.instance.deleteProject(project);
      if (!mounted) return;
      CustomToast.show(context, '已刪除「${project.title}」', ToastType.success);
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '刪除失敗：$e', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProjectsHeader(onCreate: _openCreate, onRecord: () => _openRecord()),
          const SizedBox(height: 16),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Column(
        children: [
          Text(errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadProjects, child: const Text('重新讀取')),
        ],
      );
    }

    final DateTime today = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTwoColumns = constraints.maxWidth >= visitProjectTwoColumnWidth;
        double cardWidth = constraints.maxWidth;
        if (isTwoColumns) cardWidth = (constraints.maxWidth - 16) / 2;
        final List<Widget> cards = [];
        for (final VisitProject project in _projects) {
          cards.add(SizedBox(
            width: cardWidth,
            child: VisitProjectCard(
              project: project,
              progress: VisitProjectProgress.calculate(project, _results, today),
              today: today,
              onRecord: () => _openRecord(projectId: project.id),
              onEdit: () => _openEdit(project),
              onDelete: () => _confirmDelete(project),
            ),
          ));
        }
        final bool hasMore = _resultRecords.length > _resultLimit;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VisitPendingSection(
              lists: _pendingLists,
              today: today,
              onRecord: _recordFromEvent,
              onSkip: (PendingVisitEvent event) => _setSkipped(event, true),
              onUndoSkip: (PendingVisitEvent event) => _setSkipped(event, false),
              onEditResult: _editEventResult,
            ),
            if (!_pendingLists.isEmpty) const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: cards),
            const SizedBox(height: 16),
            VisitResultListSection(
              results: _resultRecords.take(_resultLimit).toList(),
              projects: _projects,
              filterProjectId: _filterProjectId,
              hasMore: hasMore,
              onFilterChanged: _changeFilter,
              onEdit: _openEditResult,
              onShowMore: _showMoreResults,
            ),
          ],
        );
      },
    );
  }
}

/// 頁面上方：說明與「建立專案」按鈕（頁首已顯示「專案拜訪」，這裡不重複放標題）
class _ProjectsHeader extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRecord;

  const _ProjectsHeader({required this.onCreate, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '設定拜訪目標，追蹤每一期的進度',
          style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('建立專案'),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('記錄拜訪'),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ],
    );
  }
}
