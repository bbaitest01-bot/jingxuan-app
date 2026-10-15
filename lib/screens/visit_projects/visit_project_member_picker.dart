import 'package:flutter/material.dart';
import '../../services/visit_record_service.dart';
import '../../widgets/custom_toast.dart';

/// 選專案名單：搜尋＋勾選自己的客戶。按「確定」回傳 客戶編號 → 名字；按取消回傳 null
Future<Map<String, String>?> showVisitProjectMemberPicker(BuildContext context, Map<String, String> selected) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) => _MemberPickerDialog(initialSelected: selected),
  );
}

class _MemberPickerDialog extends StatefulWidget {
  final Map<String, String> initialSelected;

  const _MemberPickerDialog({required this.initialSelected});

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final Map<String, String> _selected = Map<String, String>.from(widget.initialSelected);
  List<VisitCustomerOption> _options = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final List<VisitCustomerOption> options = await VisitRecordService.instance.fetchMyCustomerOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, '讀取客戶失敗：$e', ToastType.error);
    }
  }

  void _toggle(VisitCustomerOption option, bool isChecked) {
    setState(() {
      if (isChecked) {
        _selected[option.id] = option.name;
      } else {
        _selected.remove(option.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<VisitCustomerOption> shown = VisitRecordService.filterCustomerOptions(_options, _searchController.text);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('選擇名單'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋姓名、綽號或電話',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('已選 ${_selected.length} 位', style: const TextStyle(fontSize: 13))),
                TextButton(
                  onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
                  child: const Text('全部取消'),
                ),
              ],
            ),
            Expanded(child: _buildList(shown)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('確定'),
        ),
      ],
    );
  }

  Widget _buildList(List<VisitCustomerOption> shown) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_options.isEmpty) return const Center(child: Text('還沒有客戶，請先到客戶管理新增'));
    if (shown.isEmpty) return const Center(child: Text('找不到符合的客戶'));
    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final VisitCustomerOption option = shown[index];
        String subtitle = option.phone;
        if (option.nickname.isNotEmpty) subtitle = '${option.nickname}　${option.phone}';
        return CheckboxListTile(
          dense: true,
          value: _selected.containsKey(option.id),
          title: Text(option.name),
          subtitle: subtitle.trim().isEmpty ? null : Text(subtitle.trim()),
          onChanged: (bool? value) => _toggle(option, value == true),
        );
      },
    );
  }
}
