import 'package:flutter/material.dart';

import '../../services/policy_party_service.dart';
import '../../theme/app_theme.dart';
import '../customer_policy_widgets.dart';
import 'customer_picker_dialog.dart';

/// 「保單資料」視窗裡「這張保單的人」那一區目前選的值
class PolicyPartiesValue {
  // 要保人、被保險人：null＝就是保單掛的客戶自己
  final PartyCustomer? policyholder;
  final PartyCustomer? insured;
  // 受益人：從客戶選（beneficiaryCustomer）或直接填寫（beneficiaryText）二選一
  final bool isBeneficiaryText;
  final PartyCustomer? beneficiaryCustomer;
  final String beneficiaryText;

  const PolicyPartiesValue({
    this.policyholder,
    this.insured,
    this.isBeneficiaryText = false,
    this.beneficiaryCustomer,
    this.beneficiaryText = '',
  });

  PolicyPartiesValue copyWith({
    PartyCustomer? policyholder,
    PartyCustomer? insured,
    bool? isBeneficiaryText,
    PartyCustomer? beneficiaryCustomer,
    String? beneficiaryText,
  }) {
    return PolicyPartiesValue(
      policyholder: policyholder ?? this.policyholder,
      insured: insured ?? this.insured,
      isBeneficiaryText: isBeneficiaryText ?? this.isBeneficiaryText,
      beneficiaryCustomer: beneficiaryCustomer ?? this.beneficiaryCustomer,
      beneficiaryText: beneficiaryText ?? this.beneficiaryText,
    );
  }
}

/// 「這張保單的人」：要保人、被保險人從客戶選；受益人可以選客戶或直接填（2026-11-07 模型圖）
class PolicyPartiesEditor extends StatefulWidget {
  // 保單掛的客戶（沒選時就是他自己）
  final PartyCustomer owner;
  final PolicyPartiesValue value;
  final ValueChanged<PolicyPartiesValue> onChanged;

  const PolicyPartiesEditor({super.key, required this.owner, required this.value, required this.onChanged});

  @override
  State<PolicyPartiesEditor> createState() => _PolicyPartiesEditorState();
}

class _PolicyPartiesEditorState extends State<PolicyPartiesEditor> {
  late final TextEditingController _beneficiaryTextController;

  @override
  void initState() {
    super.initState();
    _beneficiaryTextController = TextEditingController(text: widget.value.beneficiaryText);
  }

  @override
  void dispose() {
    _beneficiaryTextController.dispose();
    super.dispose();
  }

  Future<PartyCustomer?> _pick(String title) => showCustomerPickerDialog(context, title: title);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final PolicyPartiesValue value = widget.value;
    final PartyCustomer policyholder = value.policyholder ?? widget.owner;
    final PartyCustomer insured = value.insured ?? widget.owner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('這張保單的人', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink2)),
        const SizedBox(height: 6),
        _PartyButton(
          label: '要保人（出錢的人）',
          name: policyholder.name,
          onTap: () async {
            final PartyCustomer? picked = await _pick('選要保人');
            if (picked != null) widget.onChanged(value.copyWith(policyholder: picked));
          },
        ),
        const SizedBox(height: 8),
        _PartyButton(
          label: '被保險人（保障的對象，健檢算在他身上）',
          name: insured.name,
          onTap: () async {
            final PartyCustomer? picked = await _pick('選被保險人');
            if (picked != null) widget.onChanged(value.copyWith(insured: picked));
          },
        ),
        const SizedBox(height: 8),
        Text('受益人（拿到錢的人）', style: TextStyle(fontSize: 11, color: colors.ink3)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [
          SelectableChoiceChip(
            label: '從客戶選',
            isSelected: !value.isBeneficiaryText,
            onSelected: () => widget.onChanged(value.copyWith(isBeneficiaryText: false)),
          ),
          SelectableChoiceChip(
            label: '直接填寫',
            isSelected: value.isBeneficiaryText,
            onSelected: () => widget.onChanged(value.copyWith(isBeneficiaryText: true)),
          ),
        ]),
        const SizedBox(height: 6),
        if (value.isBeneficiaryText)
          TextField(
            controller: _beneficiaryTextController,
            onChanged: (String text) => widget.onChanged(value.copyWith(beneficiaryText: text)),
            decoration: InputDecoration(
              isDense: true,
              hintText: '例：法定繼承人、配偶 50%＋子女 50%',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
          )
        else
          _PartyButton(
            label: null,
            name: value.beneficiaryCustomer?.name ?? '還沒選',
            onTap: () async {
              final PartyCustomer? picked = await _pick('選受益人');
              if (picked != null) widget.onChanged(value.copyWith(beneficiaryCustomer: picked));
            },
          ),
      ],
    );
  }
}

/// 一格「選人」：上面小字說明，下面是目前選的名字，點了打開選人視窗
class _PartyButton extends StatelessWidget {
  final String? label;
  final String name;
  final VoidCallback onTap;

  const _PartyButton({required this.label, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? labelText = label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText != null) Text(labelText, style: TextStyle(fontSize: 11, color: colors.ink3)),
        if (labelText != null) const SizedBox(height: 3),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: colors.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
              Icon(Icons.search, size: 16, color: colors.ink3),
            ],
          ),
        ),
      ],
    );
  }
}
