import 'package:flutter/material.dart';

import '../services/benefit_trial_calculator.dart';
import '../theme/app_theme.dart';

/// 比較頁每一欄上方的「試算」：保額、日額、單位數（看商品用到哪個）＋年繳保費
/// 只在這次比較用，不存檔；填好後給付項目的格子會算出真正金額
class BenefitTrialPanel extends StatefulWidget {
  final BenefitTrialFields fields;
  // 台幣「元」或外幣「美元」…（輸入框單位跟著變）
  final String currencyUnit;
  final ValueChanged<BenefitTrialInput> onChanged;

  const BenefitTrialPanel({super.key, required this.fields, required this.onChanged, this.currencyUnit = '元'});

  @override
  State<BenefitTrialPanel> createState() => _BenefitTrialPanelState();
}

class _BenefitTrialPanelState extends State<BenefitTrialPanel> {
  final TextEditingController _coverageController = TextEditingController();
  final TextEditingController _dailyController = TextEditingController();
  final TextEditingController _unitsController = TextEditingController();
  final TextEditingController _premiumController = TextEditingController();

  @override
  void dispose() {
    _coverageController.dispose();
    _dailyController.dispose();
    _unitsController.dispose();
    _premiumController.dispose();
    super.dispose();
  }

  static int? _numberOf(TextEditingController controller) {
    return int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  // 任何一格改了就把四個數字一起交給比較頁；保額輸入的是萬元，這裡換成元
  void _notifyChanged() {
    int? coverageAmount;
    final int? coverageInTenThousands = _numberOf(_coverageController);
    if (coverageInTenThousands != null) {
      coverageAmount = coverageInTenThousands * 10000;
    }
    widget.onChanged(BenefitTrialInput(
      coverageAmount: coverageAmount,
      dailyAmount: _numberOf(_dailyController),
      units: _numberOf(_unitsController),
      annualPremium: _numberOf(_premiumController),
      currencyUnit: widget.currencyUnit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> inputs = [];
    if (widget.fields.needsCoverageAmount) {
      inputs.add(_TrialField(label: '保額', suffix: '萬${widget.currencyUnit}', controller: _coverageController, onChanged: _notifyChanged));
    }
    if (widget.fields.needsDailyAmount) {
      inputs.add(_TrialField(label: '日額', suffix: '元', controller: _dailyController, onChanged: _notifyChanged));
    }
    if (widget.fields.needsUnits) {
      inputs.add(_TrialField(label: '投保', suffix: '單位', controller: _unitsController, onChanged: _notifyChanged));
    }
    inputs.add(_TrialField(label: '年繳保費', suffix: widget.currencyUnit, controller: _premiumController, onChanged: _notifyChanged));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('試算（填了才算，不會存檔）', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.ink3)),
          const SizedBox(height: 6),
          ...inputs,
        ],
      ),
    );
  }
}

/// 試算的一個輸入框：左邊名稱、右邊單位
class _TrialField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _TrialField({required this.label, required this.suffix, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (String value) => onChanged(),
        style: AppTextStyles.mono(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          // 單位寫在名稱裡（suffixText 要點進去才看得到）：「保額（萬美元）」
          labelText: '$label（$suffix）',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
      ),
    );
  }
}
