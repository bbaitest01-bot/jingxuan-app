import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../services/visit_project_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_project_card.dart';
import 'visit_project_form_dialog.dart';

/// 卡片排兩欄的最小寬度
const double visitProjectTwoColumnWidth = 720;

/// 專案拜訪頁（/projects，4-2a）：我的專案卡片；建立、編輯、刪除專案。
/// 記錄拜訪（4-2b）、還沒記錄結果（4-2c）、成效圖表（4-2d）之後加在這頁。
class VisitProjectsPage extends StatefulWidget {
  const VisitProjectsPage({super.key});

  @override
  State<VisitProjectsPage> createState() => _VisitProjectsPageState();
}

class _VisitProjectsPageState extends State<VisitProjectsPage> {
  List<VisitProject> _projects = [];
  List<VisitResultSummary> _results = [];
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
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _results = results;
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
          _ProjectsHeader(onCreate: _openCreate),
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
              onEdit: () => _openEdit(project),
              onDelete: () => _confirmDelete(project),
            ),
          ));
        }
        return Wrap(spacing: 16, runSpacing: 16, children: cards);
      },
    );
  }
}

/// 頁面上方：說明與「建立專案」按鈕（頁首已顯示「專案拜訪」，這裡不重複放標題）
class _ProjectsHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _ProjectsHeader({required this.onCreate});

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
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('建立專案'),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }
}
