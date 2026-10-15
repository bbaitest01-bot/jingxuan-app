import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../models/visit_record.dart';
import '../../models/visit_result.dart';
import '../../services/customer_service.dart';
import '../../services/visit_project_service.dart';
import '../../services/visit_record_service.dart';
import '../../services/visit_result_service.dart';
import '../../widgets/custom_toast.dart';
import '../customers/customer_status_widgets.dart';
import '../visit_records/visit_record_customer_picker.dart';
import 'visit_record_link_picker.dart';

/// 預先帶進視窗的資料：從行程記錄（4-2c，有行程編號）或從專案名單記錄（沒有行程編號）
class VisitResultPreset {
  final String customerId;
  final String customerName;
  final DateTime visitedOn;
  final String? scheduleEventId;
  final String eventTitle;

  const VisitResultPreset({
    required this.customerId,
    required this.customerName,
    required this.visitedOn,
    this.scheduleEventId,
    this.eventTitle = '',
  });
}

/// 記錄拜訪（[result] 為 null）或修改一筆拜訪結果。存檔或刪除成功回傳 true。
/// [initialProjectId] 沒給時預設「日常拜訪」；[preset] 用在從行程記錄結果
Future<bool> showVisitResultFormDialog(
  BuildContext context, {
  required List<VisitProject> projects,
  String? initialProjectId,
  VisitResult? result,
  VisitResultPreset? preset,
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => VisitResultFormDialog(
      projects: projects,
      initialProjectId: initialProjectId,
      result: result,
      preset: preset,
    ),
  );
  return saved == true;
}

class VisitResultFormDialog extends StatefulWidget {
  final List<VisitProject> projects;
  final String? initialProjectId;
  final VisitResult? result;
  final VisitResultPreset? preset;

  const VisitResultFormDialog({super.key, required this.projects, this.initialProjectId, this.result, this.preset});

  @override
  State<VisitResultFormDialog> createState() => _VisitResultFormDialogState();
}

class _VisitResultFormDialogState extends State<VisitResultFormDialog> {
  final TextEditingController _noteController = TextEditingController();
  String _projectId = '';
  String _customerId = '';
  String _customerName = '';
  DateTime _visitedOn = DateUtils.dateOnly(DateTime.now());
  String? _result;
  String? _visitRecordId;
  String _visitRecordTitle = '';
  bool _isSaving = false;

  bool get _isEditing => widget.result != null;

  @override
  void initState() {
    super.initState();
    final VisitResult? original = widget.result;
    if (original != null) {
      _projectId = original.projectId;
      _customerId = original.customerId;
      _customerName = original.customerName;
      _visitedOn = original.visitedOn;
      _result = original.result;
      _noteController.text = original.note;
      _visitRecordId = original.visitRecordId;
      _visitRecordTitle = original.visitRecordTitle;
      return;
    }
    _projectId = widget.initialProjectId ?? _defaultProjectId();
    final VisitResultPreset? preset = widget.preset;
    if (preset != null) {
      _customerId = preset.customerId;
      _customerName = preset.customerName;
      _visitedOn = DateUtils.dateOnly(preset.visitedOn);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _defaultProjectId() {
    for (final VisitProject project in widget.projects) {
      if (project.isDefault) return project.id;
    }
    if (widget.projects.isEmpty) return '';
    return widget.projects.first.id;
  }

  VisitProject? _selectedProject() {
    for (final VisitProject project in widget.projects) {
      if (project.id == _projectId) return project;
    }
    return null;
  }

  VisitResultDraft _buildDraft() {
    final VisitProject? project = _selectedProject();
    return VisitResultDraft(
      projectId: _projectId,
      projectTitle: project?.title ?? '',
      customerId: _customerId,
      customerName: _customerName,
      visitedOn: _visitedOn,
      result: _result,
      note: _noteController.text,
      visitRecordId: _visitRecordId,
      visitRecordTitle: _visitRecordTitle,
      scheduleEventId: widget.preset?.scheduleEventId,
    );
  }

  Future<void> _save() async {
    final VisitResultDraft draft = _buildDraft();
    final String? problem = VisitResultService.validateDraft(draft, DateTime.now());
    if (problem != null) {
      CustomToast.show(context, problem, ToastType.warning);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final VisitResult? original = widget.result;
      if (original == null) {
        await VisitResultService.instance.createResult(draft);
      } else {
        await VisitResultService.instance.updateResult(original, draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '儲存失敗：$e', ToastType.error);
    }
  }

  // 刪除前再確認一次：客戶狀態會改回上一筆結果
  Future<void> _delete() async {
    final VisitResult? original = widget.result;
    if (original == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('刪除這筆拜訪結果？'),
        content: Text('${original.customerName} 的客戶狀態會改回上一筆結果（沒有就變成未設定）。刪除後無法還原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(confirmContext, true),
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

    setState(() => _isSaving = true);
    try {
      await VisitResultService.instance.deleteResult(original);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '刪除失敗：$e', ToastType.error);
    }
  }

  Future<void> _pickCustomer() async {
    final VisitCustomerOption? picked = await showVisitCustomerPicker(context);
    if (picked == null) return;
    setState(() {
      _customerId = picked.id;
      _customerName = picked.name;
    });
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitedOn,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _visitedOn = picked);
  }

  Future<void> _pickVisitRecord() async {
    final VisitRecord? picked = await showVisitRecordLinkPicker(context, customerId: _customerId);
    if (picked == null) return;
    setState(() {
      _visitRecordId = picked.id;
      _visitRecordTitle = picked.title;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_dialogTitle()),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_presetEventTitle().isNotEmpty) ...[
                Text('來自行程：${_presetEventTitle()}', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                const SizedBox(height: 12),
              ],
              _buildProjectPicker(),
              const SizedBox(height: 12),
              _buildCustomerRow(),
              const SizedBox(height: 12),
              _LabeledRow(
                label: '拜訪日期',
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(VisitProjectService.formatDateForDatabase(_visitedOn)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('結果', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ResultPicker(selected: _result, onChanged: (String value) => setState(() => _result = value)),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: VisitResult.maxNoteLength,
                decoration: InputDecoration(
                  labelText: '簡短備註（選填）',
                  hintText: '例：約下週帶建議書',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              _buildVisitRecordRow(),
              const SizedBox(height: 8),
              Text(
                '儲存後，這位客戶的「客戶狀態」會改成最新一筆拜訪結果。',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _isSaving ? null : _delete,
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_isSaving ? '儲存中…' : '儲存'),
        ),
      ],
    );
  }

  String _presetEventTitle() => widget.preset?.eventTitle ?? '';

  String _dialogTitle() {
    if (_isEditing) return '修改拜訪結果';
    if (widget.preset?.scheduleEventId != null) return '記錄行程結果';
    return '記錄拜訪';
  }

  Widget _buildProjectPicker() {
    final List<DropdownMenuItem<String>> items = [];
    for (final VisitProject project in widget.projects) {
      final String suffix = project.isDefault ? '（預設）' : '';
      items.add(DropdownMenuItem<String>(value: project.id, child: Text('${project.title}$suffix', overflow: TextOverflow.ellipsis)));
    }
    String? value;
    if (_selectedProject() != null) value = _projectId;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items,
      decoration: InputDecoration(
        labelText: '專案',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
      onChanged: (String? picked) => setState(() => _projectId = picked ?? ''),
    );
  }

  Widget _buildCustomerRow() {
    final VisitProject? project = _selectedProject();
    // 選了有名單的專案、客戶又不在名單裡：一樣算進度，但提醒一下
    final bool isOutsideMembers = project != null && project.hasMembers && _customerId.isNotEmpty && !project.members.containsKey(_customerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledRow(
          label: '客戶',
          child: OutlinedButton.icon(
            onPressed: _pickCustomer,
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: Text(_customerName.isEmpty ? '選擇客戶' : _customerName, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (isOutsideMembers)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('這位客戶不在專案名單裡，一樣會算進度', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ),
      ],
    );
  }

  Widget _buildVisitRecordRow() {
    final bool hasRecord = _visitRecordId != null;
    if (!hasRecord) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _pickVisitRecord,
          icon: const Icon(Icons.link, size: 18),
          label: const Text('連結拜訪紀錄（選填）'),
        ),
      );
    }
    String title = _visitRecordTitle;
    if (title.isEmpty) title = '（已連結）';
    return Row(
      children: [
        const Icon(Icons.link, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
        TextButton(
          onPressed: () => setState(() {
            _visitRecordId = null;
            _visitRecordTitle = '';
          }),
          child: const Text('取消連結'),
        ),
      ],
    );
  }
}

/// 左邊標題、右邊內容的一列
class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        Flexible(child: child),
      ],
    );
  }
}

/// ✔／△／✖ 三選一（顏色同客戶狀態）
class _ResultPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const _ResultPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = [];
    for (final String option in VisitResult.resultOptions) {
      final String symbol = CustomerService.clientStatusSymbol(option);
      final String label = CustomerService.clientStatusLabel(option);
      final Color color = customerStatusColor(option);
      final bool isSelected = selected == option;
      chips.add(ChoiceChip(
        label: Text('$symbol $label'),
        selected: isSelected,
        selectedColor: color.withValues(alpha: 0.18),
        side: BorderSide(color: isSelected ? color : Theme.of(context).dividerColor),
        labelStyle: TextStyle(color: isSelected ? color : null, fontWeight: isSelected ? FontWeight.bold : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (_) => onChanged(option),
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
