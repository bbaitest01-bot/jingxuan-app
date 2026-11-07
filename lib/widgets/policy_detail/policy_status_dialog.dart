import 'package:flutter/material.dart';

import '../../services/customer_policy_service.dart';
import '../../services/policy_detail_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import '../customer_policy_widgets.dart';

/// 「保單狀態」：六種狀態＋保單貸款；減額繳清時多一格新保額（2026-11-07 模型圖沛沛確認）
/// items 是要一起改的項目（整張保單或其中一項）；存成功回傳 true
Future<bool> showPolicyStatusDialog(BuildContext context, String customerId, List<CustomerEnrolledPolicy> items) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _PolicyStatusDialog(customerId: customerId, items: items),
  );
  return saved ?? false;
}

class _PolicyStatusDialog extends StatefulWidget {
  final String customerId;
  final List<CustomerEnrolledPolicy> items;

  const _PolicyStatusDialog({required this.customerId, required this.items});

  @override
  State<_PolicyStatusDialog> createState() => _PolicyStatusDialogState();
}

class _PolicyStatusDialogState extends State<_PolicyStatusDialog> {
  final TextEditingController _reducedAmountController = TextEditingController();
  late String _status;
  late bool _hasPolicyLoan;
  bool _isSaving = false;

  // 減額繳清的新保額寫在第一項（整張改時就是主約）
  CustomerEnrolledPolicy get _mainItem => widget.items.first;

  @override
  void initState() {
    super.initState();
    _status = _mainItem.status;
    _hasPolicyLoan = false;
    for (final CustomerEnrolledPolicy item in widget.items) {
      if (item.hasPolicyLoan) _hasPolicyLoan = true;
    }
    _reducedAmountController.text = _mainItem.reducedCoverageAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    _reducedAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final int? reducedAmount = int.tryParse(_reducedAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    try {
      await PolicyDetailService().saveStatusDetails(
        customerId: widget.customerId,
        items: widget.items,
        status: _status,
        hasPolicyLoan: _hasPolicyLoan,
        reducedItemId: _mainItem.id,
        reducedCoverageAmount: reducedAmount,
      );
      if (!mounted) return;
      CustomToast.show(context, '已改為${PolicyStatus.label(_status)}（${widget.items.length} 項）', ToastType.success);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '儲存失敗，請檢查網路後再試', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String subtitle = _mainItem.productName;
    if (widget.items.length > 1) {
      subtitle = '整張保單（${widget.items.length} 項）一起改';
    }
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('保單狀態', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(subtitle, style: TextStyle(fontSize: 12, color: colors.ink3)),
              const SizedBox(height: 12),
              PolicyStatusSelector(status: _status, onChanged: (String status) => setState(() => _status = status)),
              if (_status == PolicyStatus.reducedPaidUp) _buildReducedAmountField(colors),
              const SizedBox(height: 8),
              Divider(color: colors.line),
              CheckboxListTile(
                value: _hasPolicyLoan,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('這張保單有保單貸款', style: TextStyle(fontSize: 13, color: colors.ink)),
                subtitle: Text('保單仍然有效，只是借了錢要付利息', style: TextStyle(fontSize: 11, color: colors.ink3)),
                onChanged: (bool? checked) => setState(() => _hasPolicyLoan = checked ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
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

  /// 減額繳清：保額變小，請業務員填降級後的新保額（健檢改用這個數字）
  Widget _buildReducedAmountField(AppColors colors) {
    String label = '減額繳清後的新保額';
    if (widget.items.length > 1) label = '主約減額繳清後的新保額';
    String originalText = '原本保額：還沒填';
    final int? originalAmount = _mainItem.coverageAmount;
    if (originalAmount != null) {
      originalText = '原本保額：${PolicyDetailService.formatAmount(originalAmount)}';
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _reducedAmountController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.mono(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              suffixText: '元',
              hintText: '例：200000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
          ),
          const SizedBox(height: 4),
          Text(originalText, style: TextStyle(fontSize: 11, color: colors.ink3)),
        ],
      ),
    );
  }
}
