import 'package:flutter/material.dart';
import '../../models/visit_record.dart';
import '../../services/visit_record_service.dart';
import '../../theme/app_theme.dart';

/// 打開「選擇客戶」視窗；選了回傳那位客戶，取消回傳 null
Future<VisitCustomerOption?> showVisitCustomerPicker(BuildContext context) {
  return showDialog<VisitCustomerOption>(
    context: context,
    builder: (BuildContext dialogContext) => const _VisitCustomerPickerDialog(),
  );
}

class _VisitCustomerPickerDialog extends StatefulWidget {
  const _VisitCustomerPickerDialog();

  @override
  State<_VisitCustomerPickerDialog> createState() => _VisitCustomerPickerDialogState();
}

class _VisitCustomerPickerDialogState extends State<_VisitCustomerPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<VisitCustomerOption> _allOptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final List<VisitCustomerOption> options = await VisitRecordService.instance.fetchMyCustomerOptions();
      if (!mounted) return;
      setState(() {
        _allOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取客戶失敗：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('選擇客戶', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋姓名、暱稱或電話',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(child: Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    if (_allOptions.isEmpty) {
      return Center(child: Text('還沒有客戶，請先到「客戶管理」新增', style: TextStyle(color: context.appColors.ink3)));
    }

    final List<VisitCustomerOption> matched =
        VisitRecordService.filterCustomerOptions(_allOptions, _searchController.text);
    if (matched.isEmpty) {
      return Center(child: Text('找不到符合的客戶', style: TextStyle(color: context.appColors.ink3)));
    }
    return ListView.separated(
      itemCount: matched.length,
      separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final VisitCustomerOption option = matched[index];
        return _CustomerOptionTile(
          option: option,
          onTap: () => Navigator.of(context).pop(option),
        );
      },
    );
  }
}

class _CustomerOptionTile extends StatelessWidget {
  final VisitCustomerOption option;
  final VoidCallback onTap;

  const _CustomerOptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final String firstLetter = option.name.isNotEmpty ? option.name.substring(0, 1) : '?';

    // 副標題：暱稱、電話有填才顯示
    final List<String> details = [];
    if (option.nickname.isNotEmpty) details.add(option.nickname);
    if (option.phone.isNotEmpty) details.add(option.phone);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        backgroundColor: primaryColor.withValues(alpha: 0.12),
        child: Text(firstLetter, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      ),
      title: Text(option.name),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      onTap: onTap,
    );
  }
}

/// 單篇頁的「連結客戶」區塊：顯示目前連結的客戶，並提供選擇／更換／取消連結
class VisitRecordCustomerSection extends StatelessWidget {
  final VisitRecord record;
  final bool isBusy;
  final VoidCallback onChoose;
  final VoidCallback onClear;

  const VisitRecordCustomerSection({
    super.key,
    required this.record,
    required this.isBusy,
    required this.onChoose,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final String? customerName = record.customerName;
    final bool hasCustomer = record.customerId != null;

    String label = '尚未連結客戶';
    if (hasCustomer) {
      label = customerName ?? '（找不到客戶資料）';
      if (record.isCustomerDeleted) label = '$label（客戶已在垃圾桶）';
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: hasCustomer ? primaryColor : context.appColors.ink3),
            const SizedBox(width: 8),
            const Text('連結客戶：', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: hasCustomer ? null : context.appColors.ink3),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasCustomer)
              TextButton(
                onPressed: isBusy ? null : onClear,
                child: const Text('取消連結'),
              ),
            const SizedBox(width: 4),
            OutlinedButton(
              onPressed: isBusy ? null : onChoose,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(hasCustomer ? '更換' : '選擇客戶'),
            ),
          ],
        ),
      ),
    );
  }
}
