import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/customer_policy_service.dart';
import '../../services/policy_detail_service.dart';
import '../../services/policy_party_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import '../customer_policy_widgets.dart';
import 'policy_parties_editor.dart';

/// 「保單資料」：整張保單一起填三個人（要保人、被保險人、受益人）、生效日、繳別，
/// 每一項分開填每期保費（2026-11-07 模型圖沛沛確認）；
/// 存成功回傳 true（呼叫的地方再重新讀保單）
Future<bool> showPolicyPremiumDialog(BuildContext context, String customerId, List<CustomerEnrolledPolicy> items) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _PolicyPremiumDialog(customerId: customerId, items: items),
  );
  return saved ?? false;
}

class _PolicyPremiumDialog extends StatefulWidget {
  final String customerId;
  final List<CustomerEnrolledPolicy> items;

  const _PolicyPremiumDialog({required this.customerId, required this.items});

  @override
  State<_PolicyPremiumDialog> createState() => _PolicyPremiumDialogState();
}

class _PolicyPremiumDialogState extends State<_PolicyPremiumDialog> {
  // {保單項目 id: 每期保費輸入框}
  final Map<String, TextEditingController> _premiumControllers = {};
  DateTime? _effectiveDate;
  String? _paymentFrequency;
  bool _isSaving = false;
  // 三個人：讀完名字才顯示（owner＝保單掛的客戶）
  PartyCustomer? _owner;
  PolicyPartiesValue _parties = const PolicyPartiesValue();

  @override
  void initState() {
    super.initState();
    // 整張一起的欄位：用第一個有填的項目當預設值
    for (final CustomerEnrolledPolicy item in widget.items) {
      _effectiveDate ??= item.effectiveDate;
      _paymentFrequency ??= item.paymentFrequency;
      _premiumControllers[item.id] = TextEditingController(text: item.premium?.toString() ?? '');
    }
    _loadParties();
  }

  /// 讀三個人的名字，組成畫面上的初始值（沒填的要保人、被保險人就是保單客戶自己）
  Future<void> _loadParties() async {
    final CustomerEnrolledPolicy first = widget.items.first;
    final Map<String, String> names = await PolicyPartyService().fetchNamesFor(widget.items);
    if (!mounted) return;
    PartyCustomer? customerOf(String? id) {
      if (id == null) return null;
      return PartyCustomer(id: id, name: names[id] ?? '（已刪除的客戶）', phone: '');
    }

    final String beneficiaryText = first.beneficiaryText ?? '';
    setState(() {
      _owner = PartyCustomer(id: widget.customerId, name: names[widget.customerId] ?? '這位客戶', phone: '');
      _parties = PolicyPartiesValue(
        policyholder: customerOf(first.policyholderCustomerId),
        insured: customerOf(first.insuredCustomerId),
        isBeneficiaryText: beneficiaryText.isNotEmpty,
        beneficiaryCustomer: customerOf(first.beneficiaryCustomerId),
        beneficiaryText: beneficiaryText,
      );
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _premiumControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _premiumOf(String policyId) {
    final String text = _premiumControllers[policyId]?.text ?? '';
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  /// 幣別單位：台幣寫「元」，外幣寫代碼（USD）
  String get _currencyUnit {
    final String currency = PolicyDetailService.currencyOf(widget.items.first);
    if (currency == 'TWD') return '元';
    return currency;
  }

  Future<void> _pickEffectiveDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _effectiveDate = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final Map<String, int?> premiumByPolicyId = {};
    for (final CustomerEnrolledPolicy item in widget.items) {
      premiumByPolicyId[item.id] = _premiumOf(item.id);
    }
    try {
      await PolicyDetailService().savePremiumDetails(
        customerId: widget.customerId,
        items: widget.items,
        effectiveDate: _effectiveDate,
        paymentFrequency: _paymentFrequency,
        premiumByPolicyId: premiumByPolicyId,
      );
      // 三個人：受益人「從客戶選」和「直接填寫」只存一種
      if (_owner != null) {
        String? beneficiaryId;
        String? beneficiaryText;
        if (_parties.isBeneficiaryText) {
          beneficiaryText = _parties.beneficiaryText;
        } else {
          beneficiaryId = _parties.beneficiaryCustomer?.id;
        }
        await PolicyPartyService().saveParties(
          customerId: widget.customerId,
          items: widget.items,
          policyholderId: _parties.policyholder?.id,
          insuredId: _parties.insured?.id,
          beneficiaryId: beneficiaryId,
          beneficiaryText: beneficiaryText,
        );
      }
      if (!mounted) return;
      CustomToast.show(context, '保單資料已儲存', ToastType.success);
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
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('保單資料', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPartiesArea(),
              Divider(height: 24, color: colors.line),
              const _FieldLabel('生效日（投保日期）'),
              _buildDateField(colors),
              const SizedBox(height: 12),
              const _FieldLabel('繳別'),
              _buildFrequencyChips(),
              const SizedBox(height: 12),
              const _FieldLabel('每期保費（每一項）'),
              ..._buildPremiumFields(),
              const SizedBox(height: 8),
              _AnnualPreview(text: _annualPreviewText()),
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

  Widget _buildPartiesArea() {
    final PartyCustomer? owner = _owner;
    if (owner == null) return const LinearProgressIndicator();
    return PolicyPartiesEditor(
      owner: owner,
      value: _parties,
      onChanged: (PolicyPartiesValue value) => setState(() => _parties = value),
    );
  }

  Widget _buildDateField(AppColors colors) {
    String dateText = '還沒填，點這裡選日期';
    final DateTime? effectiveDate = _effectiveDate;
    if (effectiveDate != null) {
      dateText = DateFormat('yyyy/MM/dd').format(effectiveDate);
    }
    return OutlinedButton.icon(
      onPressed: _pickEffectiveDate,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Align(alignment: Alignment.centerLeft, child: Text(dateText, style: AppTextStyles.mono(fontSize: 13))),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }

  Widget _buildFrequencyChips() {
    final List<Widget> chips = [];
    PaymentFrequency.labels.forEach((String frequency, String label) {
      chips.add(SelectableChoiceChip(
        label: label,
        isSelected: _paymentFrequency == frequency,
        onSelected: () => setState(() => _paymentFrequency = frequency),
      ));
    });
    final Widget chipRow = Wrap(spacing: 6, runSpacing: 6, children: chips);
    // 原本有繳別、這次改成別的：每期金額通常會變（月繳每期比年繳小），提醒照保單改
    final String? originalFrequency = widget.items.first.paymentFrequency;
    final bool isFrequencyChanged = originalFrequency != null && originalFrequency != _paymentFrequency;
    if (!isFrequencyChanged) return chipRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chipRow,
        const SizedBox(height: 4),
        Text('繳別改了，下面的每期保費也要改成保單上的新金額',
            style: TextStyle(fontSize: 11, color: context.appColors.warn)),
      ],
    );
  }

  List<Widget> _buildPremiumFields() {
    final List<Widget> fields = [];
    for (final CustomerEnrolledPolicy item in widget.items) {
      String roleLabel = item.coverageRoleLabel;
      if (roleLabel.isNotEmpty) roleLabel = '$roleLabel・';
      fields.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: TextField(
          controller: _premiumControllers[item.id],
          keyboardType: TextInputType.number,
          onChanged: (String value) => setState(() {}),
          style: AppTextStyles.mono(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            labelText: '$roleLabel${item.productName}',
            suffixText: _currencyUnit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
        ),
      ));
    }
    return fields;
  }

  /// 「每期 2,050 × 12 期 = 一年 24,600 元」；躉繳、沒選繳別時換成提示
  String _annualPreviewText() {
    int periodTotal = 0;
    for (final CustomerEnrolledPolicy item in widget.items) {
      periodTotal += _premiumOf(item.id) ?? 0;
    }
    final String unit = _currencyUnit;
    final NumberFormat numberFormat = NumberFormat('#,###');
    final String? frequency = _paymentFrequency;
    if (frequency == null) {
      return '選好繳別，就會算出一年保費';
    }
    if (frequency == PaymentFrequency.single) {
      return '躉繳：一次繳清 ${numberFormat.format(periodTotal)} $unit，不算進一年總保費';
    }
    final int paymentsPerYear = PaymentFrequency.paymentsPerYear[frequency] ?? 1;
    final String periodText = numberFormat.format(periodTotal);
    final String yearText = numberFormat.format(periodTotal * paymentsPerYear);
    return '每期 $periodText × $paymentsPerYear 期 ＝ 一年 $yearText $unit';
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: context.appColors.ink2)),
    );
  }
}

/// 對話框最下面的灰底試算：一年保費怎麼算出來
class _AnnualPreview extends StatelessWidget {
  final String text;

  const _AnnualPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Text(text, style: AppTextStyles.mono(fontSize: 12, color: colors.ink2)),
    );
  }
}
