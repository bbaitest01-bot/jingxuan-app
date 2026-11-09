import 'package:flutter/material.dart';

import '../../services/scenario/claim_scenario.dart';
import '../../services/scenario/scenario_item_matcher.dart';
import '../../theme/app_theme.dart';
import '../customer_policy_widgets.dart';

/// 比較頁最上面的「情境試算」：先選發生什麼事，再填那件事的數字（2026-11-07 模型圖沛沛確認放最上面）
/// 每一款商品都用同一個情境算，下面每欄就看得出誰拿得多
class ScenarioInputPanel extends StatefulWidget {
  final ClaimScenarioInput input;
  final ValueChanged<ClaimScenarioInput> onChanged;

  const ScenarioInputPanel({super.key, required this.input, required this.onChanged});

  @override
  State<ScenarioInputPanel> createState() => _ScenarioInputPanelState();
}

class _ScenarioInputPanelState extends State<ScenarioInputPanel> {
  late final TextEditingController _daysController;
  late final TextEditingController _roomController;
  late final TextEditingController _medicalController;
  late final TextEditingController _surgeryController;
  late final TextEditingController _monthsController;

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController(text: widget.input.hospitalDays.toString());
    _roomController = TextEditingController(text: widget.input.roomDifferencePerDay.toString());
    _medicalController = TextEditingController(text: widget.input.medicalExpense.toString());
    _surgeryController = TextEditingController(text: widget.input.surgeryExpense.toString());
    _monthsController = TextEditingController(text: widget.input.careMonths.toString());
  }

  @override
  void dispose() {
    _daysController.dispose();
    _roomController.dispose();
    _medicalController.dispose();
    _surgeryController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  int _numberOf(TextEditingController controller) {
    return int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  /// 任何一格改了，就把全部格子重新讀一次交出去
  void _notifyNumbers() {
    widget.onChanged(widget.input.copyWith(
      hospitalDays: _numberOf(_daysController),
      roomDifferencePerDay: _numberOf(_roomController),
      medicalExpense: _numberOf(_medicalController),
      surgeryExpense: _numberOf(_surgeryController),
      careMonths: _numberOf(_monthsController),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> typeChips = [];
    ClaimScenarioType.labels.forEach((String type, String label) {
      typeChips.add(SelectableChoiceChip(
        label: label,
        isSelected: widget.input.type == type,
        onSelected: () => widget.onChanged(widget.input.copyWith(type: type)),
      ));
    });
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.acc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('情境試算：如果發生這件事，每款大約可以拿多少？', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
          const SizedBox(height: 2),
          Text('填一次，下面每一款都用同一個情境算；存到客戶才會保留。金額依各欄「試算」填的保額、日額、單位計算',
              style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: typeChips),
          const SizedBox(height: 12),
          _buildFieldsForType(colors),
        ],
      ),
    );
  }

  Widget _buildFieldsForType(AppColors colors) {
    final ClaimScenarioInput input = widget.input;
    switch (input.type) {
      case ClaimScenarioType.hospital:
        return _HospitalFields(
          fields: [
            _NumberField(label: '住院天數', suffix: '天', controller: _daysController, onChanged: _notifyNumbers),
            _NumberField(label: '每天病房差額（自付）', suffix: '元', controller: _roomController, onChanged: _notifyNumbers),
            _NumberField(label: '自費醫療費（藥、材料）', suffix: '元', controller: _medicalController, onChanged: _notifyNumbers),
            _NumberField(label: '手術自費（沒開刀填 0）', suffix: '元', controller: _surgeryController, onChanged: _notifyNumbers),
          ],
          summary: '自己要付的錢合計：${InsuranceAmountText.money(input.hospitalOutOfPocket)}',
        );
      case ClaimScenarioType.death:
        return _TwoChoice(
          label: '怎麼身故的',
          firstLabel: '疾病',
          secondLabel: '意外（壽險和意外險都給）',
          isFirstSelected: !input.isAccidentalDeath,
          onChanged: (bool isFirst) => widget.onChanged(input.copyWith(isAccidentalDeath: !isFirst)),
        );
      case ClaimScenarioType.cancer:
        return _HospitalFields(
          fields: [
            _TwoChoice(
              label: '癌症程度',
              firstLabel: '初期／輕度',
              secondLabel: '重度',
              isFirstSelected: !input.isSevereCancer,
              onChanged: (bool isFirst) => widget.onChanged(input.copyWith(isSevereCancer: !isFirst)),
            ),
            _NumberField(label: '癌症住院天數', suffix: '天', controller: _daysController, onChanged: _notifyNumbers),
          ],
        );
      case ClaimScenarioType.criticalIllness:
        return _TwoChoice(
          label: '疾病程度',
          firstLabel: '輕度',
          secondLabel: '重度',
          isFirstSelected: !input.isSevereCriticalIllness,
          onChanged: (bool isFirst) => widget.onChanged(input.copyWith(isSevereCriticalIllness: !isFirst)),
        );
      case ClaimScenarioType.longTermCare:
        return _HospitalFields(fields: [
          _NumberField(label: '需要照顧幾個月', suffix: '個月', controller: _monthsController, onChanged: _notifyNumbers),
        ]);
      case ClaimScenarioType.accident:
        return _HospitalFields(fields: [
          _DisabilityLevelPicker(
            level: input.disabilityLevel,
            onChanged: (int level) => widget.onChanged(input.copyWith(disabilityLevel: level)),
          ),
          _NumberField(label: '意外住院天數', suffix: '天', controller: _daysController, onChanged: _notifyNumbers),
        ]);
    }
    return const SizedBox.shrink();
  }
}

/// 金額寫法：「215,000 元」
class InsuranceAmountText {
  static String money(int amount) {
    final String digits = amount.toString();
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '$buffer 元';
  }
}

/// 一排輸入格（寬螢幕並排、窄螢幕自動換行）＋下面一行小計
class _HospitalFields extends StatelessWidget {
  final List<Widget> fields;
  final String? summary;

  const _HospitalFields({required this.fields, this.summary});

  @override
  Widget build(BuildContext context) {
    final List<Widget> sizedFields = [];
    for (final Widget field in fields) {
      sizedFields.add(SizedBox(width: 210, child: field));
    }
    final String? summaryText = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: sizedFields),
        if (summaryText != null) ...[
          const SizedBox(height: 6),
          Text(summaryText, style: AppTextStyles.mono(fontSize: 12, color: context.appColors.ink2)),
        ],
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NumberField({required this.label, required this.suffix, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (String value) => onChanged(),
      style: AppTextStyles.mono(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }
}

/// 二選一：疾病／意外、初期／重度、輕度／重度
class _TwoChoice extends StatelessWidget {
  final String label;
  final String firstLabel;
  final String secondLabel;
  final bool isFirstSelected;
  final ValueChanged<bool> onChanged;

  const _TwoChoice({
    required this.label,
    required this.firstLabel,
    required this.secondLabel,
    required this.isFirstSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.appColors.ink3)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          SelectableChoiceChip(label: firstLabel, isSelected: isFirstSelected, onSelected: () => onChanged(true)),
          SelectableChoiceChip(label: secondLabel, isSelected: !isFirstSelected, onSelected: () => onChanged(false)),
        ]),
      ],
    );
  }
}

/// 失能等級：沒有失能、1 級（100%）～11 級（5%）
class _DisabilityLevelPicker extends StatelessWidget {
  final int level;
  final ValueChanged<int> onChanged;

  const _DisabilityLevelPicker({required this.level, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<int>> options = [const DropdownMenuItem<int>(value: 0, child: Text('沒有失能'))];
    ScenarioItemMatcher.disabilityRatios.forEach((int disabilityLevel, double ratio) {
      final String percent = (ratio * 100).toStringAsFixed(0);
      options.add(DropdownMenuItem<int>(value: disabilityLevel, child: Text('$disabilityLevel 級（給 $percent%）')));
    });
    return DropdownButtonFormField<int>(
      initialValue: level,
      items: options,
      isDense: true,
      decoration: InputDecoration(
        isDense: true,
        labelText: '失能等級（1 級最嚴重）',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      onChanged: (int? value) => onChanged(value ?? 0),
    );
  }
}
