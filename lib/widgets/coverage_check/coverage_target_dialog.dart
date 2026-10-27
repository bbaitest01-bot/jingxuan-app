import 'package:flutter/material.dart';

import '../../services/coverage_check_service.dart';
import '../../theme/app_theme.dart';

/// 設定保障目標：每列一個輸入框，空白＝不設定（不判斷缺口）
/// 壽險可以輸入年收入，按「×10 帶入」（雙十原則）。沒有出處的預設值一律不給（4-L）
/// 回傳 {健檢列代號: 金額或 null}；按取消回傳 null
Future<Map<String, int?>?> showCoverageTargetDialog(BuildContext context, Map<String, int> currentTargets) {
  return showDialog<Map<String, int?>>(
    context: context,
    builder: (BuildContext dialogContext) => _CoverageTargetDialog(currentTargets: currentTargets),
  );
}

class _CoverageTargetDialog extends StatefulWidget {
  final Map<String, int> currentTargets;

  const _CoverageTargetDialog({required this.currentTargets});

  @override
  State<_CoverageTargetDialog> createState() => _CoverageTargetDialogState();
}

class _CoverageTargetDialogState extends State<_CoverageTargetDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _incomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final CoverageCheckItem item in coverageCheckItems) {
      final int? target = widget.currentTargets[item.key];
      _controllers[item.key] = TextEditingController(text: target?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _incomeController.dispose();
    super.dispose();
  }

  void _applyDoubleTenRule() {
    final int? income = int.tryParse(_incomeController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (income == null) return;
    setState(() => _controllers['life']!.text = (income * 10).toString());
  }

  void _submit() {
    final Map<String, int?> targets = {};
    _controllers.forEach((String key, TextEditingController controller) {
      final String digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
      targets[key] = int.tryParse(digits);
    });
    Navigator.pop(context, targets);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> fields = [];
    for (final CoverageCheckItem item in coverageCheckItems) {
      fields.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _controllers[item.key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            labelText: item.label,
            suffixText: item.unit,
            hintText: '不設定就留空白',
            helperText: item.hint,
            helperMaxLines: 2,
          ),
        ),
      ));
      if (item.key == 'life') {
        fields.add(_IncomeHelper(controller: _incomeController, onApply: _applyDoubleTenRule));
      }
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('設定保障目標', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('依這位客戶的需求填寫（例：想住單人房、有房貸）；留空白的項目只顯示目前有多少。',
                  style: TextStyle(fontSize: 12, color: colors.ink3)),
              const SizedBox(height: 10),
              ...fields,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _submit,
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
}

/// 壽險下方：年收入 × 10 帶入（雙十原則）
class _IncomeHelper extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onApply;

  const _IncomeHelper({required this.controller, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, labelText: '參考：客戶年收入', suffixText: '元'),
            ),
          ),
          TextButton(onPressed: onApply, child: const Text('×10 帶入壽險')),
        ],
      ),
    );
  }
}
