import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/visit_record.dart';
import '../../../main.dart';
import '../../../router/app_routes.dart';
import '../../../services/customer_policy_service.dart';
import '../../../services/customer_service.dart';
import '../../../services/visit_record_service.dart';
import '../../../widgets/custom_toast.dart';
import '../customer_form_dialog.dart';
import '../customer_status_widgets.dart';
import 'customer_detail_sections.dart';

/// 客戶細節整頁（/customers/:id，問題 C3）：由上到下 基本資料、保單、拜訪紀錄（C7）
/// 「編輯」打開客戶表單（含性別，4-3b 沛沛決定）；快速預覽抽屜仍可從客戶列表打開
class CustomerDetailPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  Map<String, dynamic>? _customer;
  List<CustomerEnrolledPolicy> _policies = [];
  List<VisitRecord> _visitRecords = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant CustomerDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一個外框換成另一位客戶時要重新讀
    if (oldWidget.customerId != widget.customerId) _loadAll();
  }

  // 依序讀客戶、保單、拜訪紀錄；客戶找不到就不再讀其他
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final Map<String, dynamic>? customer = await CustomerService.instance.fetchCustomer(widget.customerId);
      if (customer == null) {
        if (!mounted) return;
        setState(() {
          _customer = null;
          _isLoading = false;
        });
        return;
      }
      final List<CustomerEnrolledPolicy> policies = await CustomerPolicyService().getCustomerPolicies(widget.customerId);
      final List<VisitRecord> records = await VisitRecordService.instance.fetchRecordsForCustomer(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _policies = policies;
        _visitRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取客戶資料失敗：$e';
        _isLoading = false;
      });
    }
  }

  void _openEditForm(Map<String, dynamic> customer) {
    showCustomerFormDialog(
      context,
      customer: customer,
      onSubmit: (CustomerFormData form) => _saveForm(customer, form),
    );
  }

  // 存檔：先處理頭像，再更新客戶資料，最後整頁重讀
  Future<void> _saveForm(Map<String, dynamic> customer, CustomerFormData form) async {
    if (isOfflineMode) {
      CustomToast.show(context, '目前為離線預覽模式，無法修改客戶資料。', ToastType.warning);
      return;
    }
    try {
      final String existingAvatarUrl = customer['avatar_url']?.toString() ?? '';
      final String avatarUrl = await CustomerService.instance.resolveAvatarUrl(form, existingAvatarUrl);
      await CustomerService.instance.updateCustomer(widget.customerId, form, avatarUrl);
      if (!mounted) return;
      CustomToast.show(context, '已更新客戶 ${form.name} 的資料', ToastType.success);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '修改失敗：$e', ToastType.error);
    }
  }

  void _backToCustomers() => context.go(AppRoutes.customers);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) return _buildMessage(errorMessage);
    final Map<String, dynamic>? customer = _customer;
    if (customer == null) return _buildMessage('找不到這位客戶（可能已刪除或不是你的客戶）');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(customer),
              const SizedBox(height: 16),
              CustomerBasicInfoSection(customer: customer),
              const SizedBox(height: 16),
              CustomerPoliciesSection(policies: _policies),
              const SizedBox(height: 16),
              CustomerVisitRecordsSection(records: _visitRecords),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> customer) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final String name = customer['name']?.toString() ?? '';
    final String nickname = customer['nickname']?.toString() ?? '';
    final String firstLetter = name.isNotEmpty ? name.substring(0, 1) : '?';

    String titleText = name;
    if (nickname.isNotEmpty) titleText = '$name（$nickname）';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _backToCustomers,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('返回客戶管理'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              child: Text(firstLetter, style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomerNameWithStatus(
                name: titleText,
                status: customer['client_status'] as String?,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openEditForm(customer),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('編輯'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _backToCustomers,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回客戶管理'),
          ),
        ],
      ),
    );
  }
}
