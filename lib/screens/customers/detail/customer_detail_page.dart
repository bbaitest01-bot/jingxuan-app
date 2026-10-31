import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/visit_record.dart';
import '../../../main.dart';
import '../../../router/app_routes.dart';
import '../../../services/customer_policy_service.dart';
import '../../../services/customer_service.dart';
import '../../../services/visit_record_service.dart';
import '../../../widgets/custom_toast.dart';
import '../../../widgets/policy_group_card.dart';
import '../../../widgets/coverage_check/customer_coverage_check_section.dart';
import '../../../widgets/coverage_check/policy_coverage_dialog.dart';
import '../../../widgets/scan_policy/scan_policy_flow.dart';
import '../customer_form_dialog.dart';
import '../customer_status_widgets.dart';
import '../../../theme/app_theme.dart';
import 'customer_detail_sections.dart';
import '../../../widgets/tour_target.dart';

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

  /// 保單健檢：編輯一張保單的保障類別、保額或實支計畫，存好後重新讀保單（健檢跟著重算）
  Future<void> _editCoverage(CustomerEnrolledPolicy policy) async {
    final bool saved = await showPolicyCoverageDialog(context, policy);
    if (saved && mounted) {
      await _loadAll();
    }
  }

  /// 一項或整張保單改有效／已失效（D21），成功後重新讀保單（健檢跟著重算）
  Future<void> _setPolicyStatus(List<CustomerEnrolledPolicy> items, String status) async {
    if (await savePolicyStatus(context, widget.customerId, items, status) && mounted) {
      await _loadAll();
    }
  }

  /// 刪除一項或整張保單（D21，卡片上已先確認）
  Future<void> _deletePolicies(List<CustomerEnrolledPolicy> items) async {
    if (await deletePolicyItems(context, widget.customerId, items) && mounted) {
      await _loadAll();
    }
  }

  /// 掃描保單（第 5 階段 E）：已經在這位客戶的頁面，不用再選客戶；存入後重新讀保單
  Future<void> _scanPolicy(Map<String, dynamic> customer) async {
    final bool saved = await startPolicyScan(
      context,
      customerId: widget.customerId,
      customerName: customer['name']?.toString(),
    );
    if (saved && mounted) {
      await _loadAll();
    }
  }

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
              // 新手導覽第 6 步亮保障健檢
              TourTarget(
                id: 'customerDetail.policies',
                child: CustomerCoverageCheckSection(
                  customerId: widget.customerId,
                  customerName: customer['name']?.toString() ?? '',
                  policies: _policies,
                ),
              ),
              const SizedBox(height: 16),
              CustomerPoliciesSection(
                policies: _policies,
                onScanPressed: () => _scanPolicy(customer),
                onEditCoverage: _editCoverage,
                onSetStatus: _setPolicyStatus,
                onDelete: _deletePolicies,
              ),
              const SizedBox(height: 16),
              CustomerVisitRecordsSection(records: _visitRecords),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> customer) {
    final Color primaryColor = context.appColors.acc;
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
              backgroundColor: context.appColors.accSoft,
              child: Text(firstLetter, style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomerNameWithStatus(
                name: titleText,
                status: customer['client_status'] as String?,
                style: AppTextStyles.serif(fontSize: 24, color: context.appColors.ink),
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
