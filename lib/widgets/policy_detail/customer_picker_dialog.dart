import 'package:flutter/material.dart';

import '../../services/policy_party_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';

/// 從自己的客戶名單選一個人（要保人、被保險人、受益人共用）；找不到可以只填名字新增
/// 選好回傳那位客戶，按取消回傳 null
Future<PartyCustomer?> showCustomerPickerDialog(BuildContext context, {required String title}) {
  return showDialog<PartyCustomer>(
    context: context,
    builder: (BuildContext dialogContext) => _CustomerPickerDialog(title: title),
  );
}

class _CustomerPickerDialog extends StatefulWidget {
  final String title;

  const _CustomerPickerDialog({required this.title});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<PartyCustomer> _customers = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<PartyCustomer> customers = await PolicyPartyService().fetchMyCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, '讀取客戶名單失敗，請檢查網路後再試', ToastType.error);
    }
  }

  /// 名字有包含搜尋字的客戶
  List<PartyCustomer> _matchedCustomers() {
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) return _customers;
    final List<PartyCustomer> matched = [];
    for (final PartyCustomer customer in _customers) {
      if (customer.name.contains(keyword)) matched.add(customer);
    }
    return matched;
  }

  /// 搜尋的名字在名單上找不到同名的人，才出現「新增為客戶」
  bool _canCreate(List<PartyCustomer> matched) {
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) return false;
    for (final PartyCustomer customer in matched) {
      if (customer.name == keyword) return false;
    }
    return true;
  }

  Future<void> _createAndPick() async {
    setState(() => _isCreating = true);
    try {
      final PartyCustomer customer = await PolicyPartyService().createQuickCustomer(_searchController.text);
      if (!mounted) return;
      CustomToast.show(context, '已新增客戶「${customer.name}」，其他資料之後可以到客戶頁補', ToastType.success);
      Navigator.pop(context, customer);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      CustomToast.show(context, '新增客戶失敗，請檢查網路後再試', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<PartyCustomer> matched = _matchedCustomers();
    final List<Widget> tiles = [];
    if (_canCreate(matched)) {
      tiles.add(ListTile(
        dense: true,
        leading: Icon(Icons.person_add_alt_1_outlined, color: colors.acc),
        title: Text('新增「${_searchController.text.trim()}」為客戶（只要名字）', style: TextStyle(fontSize: 13, color: colors.acc)),
        onTap: _isCreating ? null : _createAndPick,
      ));
    }
    for (final PartyCustomer customer in matched) {
      tiles.add(ListTile(
        dense: true,
        title: Text(customer.name, style: TextStyle(fontSize: 13, color: colors.ink)),
        subtitle: customer.phone.isEmpty ? null : Text(customer.phone, style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
        onTap: () => Navigator.pop(context, customer),
      ));
    }

    Widget listArea = ListView(shrinkWrap: true, children: tiles);
    if (_isLoading) listArea = const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(widget.title, style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 380,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (String value) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: '輸入名字搜尋',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: listArea),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      ],
    );
  }
}
