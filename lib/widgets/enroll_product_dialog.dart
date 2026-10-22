import 'package:flutter/material.dart';
import '../services/customer_policy_service.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'custom_toast.dart';

/// 「為名下客戶規劃」：選一位自己的客戶，把這款商品加入他的已投保保單
Future<void> showEnrollProductDialog(BuildContext context, InsuranceProduct product) async {
  final CustomerPolicyService policyService = CustomerPolicyService();

  List<Map<String, dynamic>> customers = [];
  try {
    customers = await policyService.fetchMyCustomersForEnroll();
  } catch (error) {
    if (context.mounted) {
      CustomToast.show(context, '讀取客戶資料失敗，請稍後再試', ToastType.error);
    }
    return;
  }
  if (!context.mounted) return;

  if (customers.isEmpty) {
    CustomToast.show(context, '名下還沒有客戶，請先到「客戶管理」新增', ToastType.warning);
    return;
  }

  final String? selectedCustomerId = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _EnrollProductDialog(product: product, customers: customers),
  );
  if (selectedCustomerId == null || !context.mounted) return;

  final bool success = await policyService.enrollProductForCustomer(
    customerId: selectedCustomerId,
    product: product,
  );
  if (!context.mounted) return;
  if (success) {
    CustomToast.show(context, '已把「${product.productName}」加入客戶保單', ToastType.success);
  } else {
    CustomToast.show(context, '加入失敗，請檢查網路後再試', ToastType.error);
  }
}

class _EnrollProductDialog extends StatefulWidget {
  final InsuranceProduct product;
  final List<Map<String, dynamic>> customers;

  const _EnrollProductDialog({required this.product, required this.customers});

  @override
  State<_EnrollProductDialog> createState() => _EnrollProductDialogState();
}

class _EnrollProductDialogState extends State<_EnrollProductDialog> {
  late String _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customers.first['id'].toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<DropdownMenuItem<String>> customerItems = [];
    for (final Map<String, dynamic> customer in widget.customers) {
      final String phone = customer['phone']?.toString() ?? '未提供電話';
      customerItems.add(DropdownMenuItem<String>(
        value: customer['id'].toString(),
        child: Text('${customer['name']}（$phone）', style: const TextStyle(fontSize: 13)),
      ));
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(
        '加入客戶保單',
        style: AppTextStyles.serif(fontSize: 16, color: colors.ink),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accSoft,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.product.companyName}・${widget.product.insuranceTypeLabel}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.product.productName, style: TextStyle(fontSize: 13, color: colors.ink)),
                  const SizedBox(height: 4),
                  Text('理賠限額：比價欄位建置中', style: TextStyle(fontSize: 11, color: colors.ink3)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('選擇客戶：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCustomerId,
              isExpanded: true,
              items: customerItems,
              onChanged: (String? customerId) {
                if (customerId != null) {
                  setState(() => _selectedCustomerId = customerId);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedCustomerId),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('加入保單'),
        ),
      ],
    );
  }
}
