import 'package:flutter/material.dart';

import '../../services/benefit_plan_service.dart';
import '../../services/coverage_check_service.dart';
import '../../services/customer_policy_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';

/// 編輯一張保單的「保障類別、保額、實支計畫」（保單健檢 4-L）；存成功回傳 true
Future<bool> showPolicyCoverageDialog(BuildContext context, CustomerEnrolledPolicy policy) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _PolicyCoverageDialog(policy: policy),
  );
  return saved ?? false;
}

class _PolicyCoverageDialog extends StatefulWidget {
  final CustomerEnrolledPolicy policy;

  const _PolicyCoverageDialog({required this.policy});

  @override
  State<_PolicyCoverageDialog> createState() => _PolicyCoverageDialogState();
}

class _PolicyCoverageDialogState extends State<_PolicyCoverageDialog> {
  final TextEditingController _amountController = TextEditingController();
  String? _productCategory;
  String? _selectedCategory;
  List<InsuranceBenefitPlan> _plans = [];
  String? _selectedPlanId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.policy.coverageAmount?.toString() ?? '';
    _selectedPlanId = widget.policy.benefitPlanId;
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final String productId = widget.policy.policyClauseId;
    final Map<String, String?> categories = await CoverageCheckService().fetchProductCategories([productId]);
    final Map<String, List<InsuranceBenefitPlan>> plans = await BenefitPlanService().fetchPlansForProducts([productId]);
    if (!mounted) return;
    setState(() {
      _productCategory = categories[productId];
      _selectedCategory = widget.policy.coverageCategory ?? _productCategory;
      _plans = plans[productId] ?? const [];
      // 還沒選計畫：用保單上的「計畫三」試著自動對
      _selectedPlanId ??= CoverageCheckService.matchPlan(widget.policy.planOrAmount, _plans)?.id;
      // 還沒填保額：用保單上的「50 萬元」試著自動轉
      if (_amountController.text.isEmpty) {
        _amountController.text = CoverageCheckService.parseAmount(widget.policy.planOrAmount)?.toString() ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    // 跟商品分類一樣就不另外存（之後商品分類修正時會跟著變）
    String? categoryToSave = _selectedCategory;
    if (categoryToSave == _productCategory) {
      categoryToSave = null;
    }
    final bool isReimbursement = _selectedCategory == CoverageCategory.reimbursement;
    final int? amount = int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    try {
      await CoverageCheckService().updatePolicyCoverage(
        customerId: widget.policy.customerId,
        policyId: widget.policy.id,
        coverageCategory: categoryToSave,
        coverageAmount: isReimbursement ? null : amount,
        benefitPlanId: isReimbursement ? _selectedPlanId : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '儲存失敗，請稍後再試', ToastType.error);
    }
  }

  String _amountUnit() {
    if (_selectedCategory == CoverageCategory.dailyHospital) return '元／日';
    if (_selectedCategory == CoverageCategory.longTermCare) return '元／月';
    return '元';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('保障與保額', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: _isLoading ? const LinearProgressIndicator() : _buildForm(colors),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        ElevatedButton(
          onPressed: _isLoading || _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Widget _buildForm(AppColors colors) {
    final List<DropdownMenuItem<String>> categoryItems = [];
    CoverageCategory.labels.forEach((String key, String label) {
      categoryItems.add(DropdownMenuItem<String>(value: key, child: Text(label)));
    });
    final bool isReimbursement = _selectedCategory == CoverageCategory.reimbursement;
    final String planText = widget.policy.planOrAmount ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.policy.productName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        if (planText.isNotEmpty) Text('保單上寫：$planText', style: TextStyle(fontSize: 12, color: colors.ink3)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          items: categoryItems,
          decoration: const InputDecoration(isDense: true, labelText: '保障類別'),
          onChanged: (String? category) => setState(() => _selectedCategory = category),
        ),
        const SizedBox(height: 12),
        if (isReimbursement) _buildPlanPicker(colors) else _buildAmountField(),
      ],
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(isDense: true, labelText: '保額', suffixText: _amountUnit(), hintText: '例：1000000'),
    );
  }

  Widget _buildPlanPicker(AppColors colors) {
    if (_plans.isEmpty) {
      return Text('這款商品還沒有限額表，暫時無法計入實支實付。', style: TextStyle(fontSize: 12, color: colors.warn));
    }
    final List<DropdownMenuItem<String>> planItems = [];
    for (final InsuranceBenefitPlan plan in _plans) {
      planItems.add(DropdownMenuItem<String>(value: plan.id, child: Text(plan.optionLabel, overflow: TextOverflow.ellipsis)));
    }
    String? selected = _selectedPlanId;
    if (!planItems.any((DropdownMenuItem<String> item) => item.value == selected)) {
      selected = null;
    }
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      items: planItems,
      decoration: const InputDecoration(isDense: true, labelText: '計畫'),
      onChanged: (String? planId) => setState(() => _selectedPlanId = planId),
    );
  }
}
