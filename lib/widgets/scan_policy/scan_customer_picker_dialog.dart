import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 選好的客戶（id 與姓名）；isNewCustomer 代表是當場新增、只填了姓名
class ScanCustomerChoice {
  final String? customerId;
  final String customerName;

  const ScanCustomerChoice({required this.customerId, required this.customerName});

  bool get isNewCustomer => customerId == null;
}

/// 掃描保單第 ① 步：「這份保單是誰的？」選現有客戶，或只填姓名新增
Future<ScanCustomerChoice?> showScanCustomerPickerDialog(
  BuildContext context,
  List<Map<String, dynamic>> customers,
) {
  return showDialog<ScanCustomerChoice>(
    context: context,
    builder: (BuildContext dialogContext) => _ScanCustomerPickerDialog(customers: customers),
  );
}

/// 電話只露出前四碼和後三碼，例：0912-***-678
String maskPhoneNumber(String phone) {
  final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 8) {
    return phone;
  }
  return '${digits.substring(0, 4)}-***-${digits.substring(digits.length - 3)}';
}

class _ScanCustomerPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> customers;

  const _ScanCustomerPickerDialog({required this.customers});

  @override
  State<_ScanCustomerPickerDialog> createState() => _ScanCustomerPickerDialogState();
}

class _ScanCustomerPickerDialogState extends State<_ScanCustomerPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newNameController = TextEditingController();
  bool _isAddingNewCustomer = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredCustomers() {
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return widget.customers;
    }
    final List<Map<String, dynamic>> matchedCustomers = [];
    for (final Map<String, dynamic> customer in widget.customers) {
      final String name = customer['name']?.toString() ?? '';
      final String phone = customer['phone']?.toString() ?? '';
      if (name.contains(keyword) || phone.contains(keyword)) {
        matchedCustomers.add(customer);
      }
    }
    return matchedCustomers;
  }

  void _confirmNewCustomer() {
    final String name = _newNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.pop(context, ScanCustomerChoice(customerId: null, customerName: name));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('掃描保單', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: _isAddingNewCustomer ? _buildNewCustomerForm(colors) : _buildCustomerList(colors),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        if (_isAddingNewCustomer)
          ElevatedButton(
            onPressed: _confirmNewCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: const Text('下一步'),
          ),
      ],
    );
  }

  Widget _buildCustomerList(AppColors colors) {
    final List<Map<String, dynamic>> customers = _filteredCustomers();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('這份保單是誰的？', style: TextStyle(fontSize: 13, color: colors.ink2)),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '搜尋客戶姓名、電話…',
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: customers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('找不到符合的客戶', style: TextStyle(fontSize: 12, color: colors.ink3)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: customers.length,
                  itemBuilder: (BuildContext context, int index) => _buildCustomerRow(colors, customers[index]),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _isAddingNewCustomer = true),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('新增客戶（只要填姓名）'),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerRow(AppColors colors, Map<String, dynamic> customer) {
    final String name = customer['name']?.toString() ?? '未命名客戶';
    final String phone = customer['phone']?.toString() ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: () => Navigator.pop(
        context,
        ScanCustomerChoice(customerId: customer['id'].toString(), customerName: name),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: colors.ink))),
            if (phone.isNotEmpty)
              Text(maskPhoneNumber(phone), style: AppTextStyles.mono(fontSize: 12, color: colors.ink3)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCustomerForm(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('新增客戶', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        const SizedBox(height: 4),
        Text('先填姓名就好，電話等資料之後到客戶頁補上。', style: TextStyle(fontSize: 12, color: colors.ink3)),
        const SizedBox(height: 10),
        TextField(
          controller: _newNameController,
          autofocus: true,
          onSubmitted: (_) => _confirmNewCustomer(),
          decoration: const InputDecoration(hintText: '客戶姓名', isDense: true),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => setState(() => _isAddingNewCustomer = false),
          child: const Text('← 改選現有客戶'),
        ),
      ],
    );
  }
}
