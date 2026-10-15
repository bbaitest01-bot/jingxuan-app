import 'package:flutter/material.dart';
import '../../models/visit_project.dart';
import '../../services/visit_project_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_project_member_picker.dart';

/// 建立或編輯專案的視窗。[project] 為 null＝建立；[initialMembers] 用在客戶管理多選後建立專案。
/// 存檔成功回傳 true。
Future<bool> showVisitProjectFormDialog(
  BuildContext context, {
  VisitProject? project,
  Map<String, String> initialMembers = const {},
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => VisitProjectFormDialog(project: project, initialMembers: initialMembers),
  );
  return saved == true;
}

class VisitProjectFormDialog extends StatefulWidget {
  final VisitProject? project;
  final Map<String, String> initialMembers;

  const VisitProjectFormDialog({super.key, this.project, this.initialMembers = const {}});

  @override
  State<VisitProjectFormDialog> createState() => _VisitProjectFormDialogState();
}

class _VisitProjectFormDialogState extends State<VisitProjectFormDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  bool _isRange = false;
  String _repeatPeriod = VisitProject.periodMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, String> _members = {};
  bool _isSaving = false;

  bool get _isEditing => widget.project != null;
  bool get _isDefault => widget.project?.isDefault == true;

  @override
  void initState() {
    super.initState();
    final VisitProject? project = widget.project;
    if (project == null) {
      _targetController.text = '10';
      _members = Map<String, String>.from(widget.initialMembers);
      return;
    }
    _titleController.text = project.title;
    _purposeController.text = project.purpose;
    _targetController.text = project.targetCount.toString();
    _isRange = project.isRange;
    if (!project.isRange) _repeatPeriod = project.periodType;
    _startDate = project.startDate;
    _endDate = project.endDate;
    _members = Map<String, String>.from(project.members);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _purposeController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  VisitProjectDraft _buildDraft() {
    final int targetCount = int.tryParse(_targetController.text.trim()) ?? 0;
    return VisitProjectDraft(
      title: _isDefault ? VisitProject.defaultTitle : _titleController.text,
      purpose: _purposeController.text,
      periodType: _isRange ? VisitProject.periodRange : _repeatPeriod,
      startDate: _startDate,
      endDate: _endDate,
      targetCount: targetCount,
      members: _members,
    );
  }

  Future<void> _save() async {
    final VisitProjectDraft draft = _buildDraft();
    final String? problem = VisitProjectService.validateDraft(draft);
    if (problem != null) {
      CustomToast.show(context, problem, ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final VisitProject? project = widget.project;
      if (project == null) {
        await VisitProjectService.instance.createProject(draft);
      } else {
        await VisitProjectService.instance.updateProject(project, draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '儲存失敗：$e', ToastType.error);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    DateTime initial = now;
    final DateTime? current = isStart ? _startDate : _endDate;
    if (current != null) initial = current;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickMembers() async {
    final Map<String, String>? picked = await showVisitProjectMemberPicker(context, _members);
    if (picked == null) return;
    setState(() => _members = Map<String, String>.from(picked));
  }

  @override
  Widget build(BuildContext context) {
    final String dialogTitle = _isEditing ? '編輯專案' : '建立專案';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(dialogTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleField(),
              const SizedBox(height: 12),
              if (!_isDefault) ...[
                _OutlinedField(controller: _purposeController, label: '說明（選填）', maxLines: 2),
                const SizedBox(height: 16),
              ],
              _buildPeriodSection(),
              const SizedBox(height: 16),
              _OutlinedField(
                controller: _targetController,
                label: '目標次數（每一期）',
                keyboardType: TextInputType.number,
              ),
              if (!_isDefault) ...[
                const SizedBox(height: 16),
                _MemberSection(members: _members, onPick: _pickMembers),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_isSaving ? '儲存中…' : '儲存'),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    if (_isDefault) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(VisitProject.defaultTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('預設專案：名稱固定、不能刪除，可以調整週期與目標次數；任何客戶的拜訪都算'),
      );
    }
    return _OutlinedField(controller: _titleController, label: '專案名稱', hintText: '例：十一月轉介紹衝刺');
  }

  Widget _buildPeriodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('期間', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: false, label: Text('重複')),
            ButtonSegment<bool>(value: true, label: Text('固定期間')),
          ],
          selected: {_isRange},
          showSelectedIcon: false,
          onSelectionChanged: (Set<bool> value) => setState(() => _isRange = value.first),
        ),
        const SizedBox(height: 10),
        if (!_isRange) _buildRepeatPicker(),
        if (_isRange) _buildRangePicker(),
      ],
    );
  }

  Widget _buildRepeatPicker() {
    final List<DropdownMenuItem<String>> items = [];
    for (final String period in VisitProject.repeatPeriods) {
      items.add(DropdownMenuItem<String>(value: period, child: Text(VisitProject.periodLabel(period))));
    }
    return Row(
      children: [
        DropdownButton<String>(
          value: _repeatPeriod,
          items: items,
          onChanged: (String? value) => setState(() => _repeatPeriod = value ?? VisitProject.periodMonth),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('每一期結束後，進度從 0 開始', style: TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildRangePicker() {
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    final String startText = start == null ? '開始日' : VisitProjectService.formatDateForDatabase(start);
    final String endText = end == null ? '結束日' : VisitProjectService.formatDateForDatabase(end);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickDate(isStart: true),
          icon: const Icon(Icons.event, size: 18),
          label: Text(startText),
        ),
        const Text('～'),
        OutlinedButton.icon(
          onPressed: () => _pickDate(isStart: false),
          icon: const Icon(Icons.event, size: 18),
          label: Text(endText),
        ),
      ],
    );
  }
}

/// 有外框、圓角 12 的輸入框
class _OutlinedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _OutlinedField({
    required this.controller,
    required this.label,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }
}

/// 名單區：顯示已選的客戶，按鈕打開選擇視窗
class _MemberSection extends StatelessWidget {
  final Map<String, String> members;
  final VoidCallback onPick;

  const _MemberSection({required this.members, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final Color mutedColor = Theme.of(context).hintColor;
    final List<String> names = members.values.toList();
    String summary = '不選＝任何客戶的拜訪都算';
    if (names.isNotEmpty) {
      final String more = names.length > 8 ? ' 等' : '';
      summary = '${names.length} 位：${names.take(8).join('、')}$more';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('客戶名單（選填）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('選擇名單'),
            ),
          ],
        ),
        Text(summary, style: TextStyle(fontSize: 13, color: mutedColor)),
      ],
    );
  }
}
