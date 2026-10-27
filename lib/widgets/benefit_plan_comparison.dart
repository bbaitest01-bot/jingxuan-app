import 'package:flutter/material.dart';

import '../services/benefit_plan_service.dart';
import '../theme/app_theme.dart';

/// 保單比較頁「理賠限額（實支實付）」區塊的列與計畫選單（D14；模型圖 2026-10-27 沛沛確認）

/// 沒有限額表的商品（不是實支實付）在「類型」列顯示這段
const String notReimbursementText = '不是實支實付（沒有限額表）';

/// 總額型商品，分項目的列顯示這段
const String notItemizedText = '不分項目';

/// 表格下方的說明（2026-10-27 沛沛問「會不會不知道計劃是多少錢」）
const String benefitAmountNotice = '金額為理賠上限（最多賠多少），不是保費；保費依年齡、性別不同，請查各公司費率表。';

/// 比較的列：類型＋7 項＋說明。順序就是畫面上的順序
const List<String> benefitRowLabels = [
  '類型',
  '每日病房',
  '住院醫療費用',
  '住院手術',
  '門診手術',
  '總限額',
  '自負額',
  '住院日額',
  '說明',
];

/// 某一列、某個計畫要顯示的文字；plan 是 null 代表這款商品沒有限額表
String benefitRowText(String label, InsuranceBenefitPlan? plan) {
  if (plan == null) {
    if (label == '類型') {
      return notReimbursementText;
    }
    return '—';
  }
  switch (label) {
    case '類型':
      return plan.typeLabel;
    case '每日病房':
      return _itemizedAmount(plan, plan.roomDailyLimit);
    case '住院醫療費用':
      return _hospitalExpenseText(plan);
    case '住院手術':
      return _surgeryText(plan);
    case '門診手術':
      return _itemizedAmount(plan, plan.outpatientSurgeryLimit);
    case '總限額':
      return _totalLimitText(plan);
    case '自負額':
      return _deductibleText(plan);
    case '住院日額':
      return _amountOrDash(plan.dailyHospitalBenefit);
    case '說明':
      return plan.note ?? '—';
  }
  return '—';
}

String _amountOrDash(int? amount) {
  if (amount == null) {
    return '—';
  }
  return InsuranceBenefitPlan.formatAmount(amount);
}

/// 總額型不分項目；其他類型有數字就顯示
String _itemizedAmount(InsuranceBenefitPlan plan, int? amount) {
  if (plan.isTotalType) {
    return notItemizedText;
  }
  return _amountOrDash(amount);
}

String _hospitalExpenseText(InsuranceBenefitPlan plan) {
  final String amountText = _itemizedAmount(plan, plan.hospitalExpenseLimit);
  if (plan.hospitalExpenseIncludesSurgery && plan.hospitalExpenseLimit != null) {
    return '$amountText（含手術）';
  }
  return amountText;
}

/// 國泰等「住院醫療費用」已含手術的商品，沒有獨立的手術限額
String _surgeryText(InsuranceBenefitPlan plan) {
  if (plan.isTotalType) {
    return notItemizedText;
  }
  final int? surgery = plan.surgeryLimit;
  if (surgery != null) {
    return InsuranceBenefitPlan.formatAmount(surgery);
  }
  if (plan.hospitalExpenseIncludesSurgery) {
    return '— 含在住院醫療費用';
  }
  return '—';
}

String _totalLimitText(InsuranceBenefitPlan plan) {
  final List<String> parts = [];
  final int? perAdmission = plan.perAdmissionTotalLimit;
  if (perAdmission != null) {
    parts.add('每次住院 ${InsuranceBenefitPlan.formatAmount(perAdmission)}');
  }
  final int? annual = plan.annualTotalLimit;
  if (annual != null) {
    parts.add('每年 ${InsuranceBenefitPlan.formatAmount(annual)}');
  }
  final int? lifetime = plan.lifetimeTotalLimit;
  if (lifetime != null) {
    parts.add('累計 ${InsuranceBenefitPlan.formatAmount(lifetime)}');
  }
  if (parts.isEmpty && plan.isTotalType) {
    return '累計總限額（依投保單位）';
  }
  if (parts.isEmpty) {
    return '—';
  }
  return parts.join('／');
}

String _deductibleText(InsuranceBenefitPlan plan) {
  final List<String> parts = [];
  final int? room = plan.roomDeductible;
  if (room != null) {
    parts.add('病房 ${InsuranceBenefitPlan.formatAmount(room)}');
  }
  final int? hospitalExpense = plan.hospitalExpenseDeductible;
  if (hospitalExpense != null) {
    parts.add('住院醫療 ${InsuranceBenefitPlan.formatAmount(hospitalExpense)}');
  }
  final int? outpatient = plan.outpatientSurgeryDeductible;
  if (outpatient != null) {
    parts.add('門診手術 ${InsuranceBenefitPlan.formatAmount(outpatient)}');
  }
  if (parts.isEmpty) {
    return '—';
  }
  return parts.join('／');
}

/// 每欄上方的計畫選單；只有一個計畫時直接顯示名稱
class BenefitPlanSelector extends StatelessWidget {
  final List<InsuranceBenefitPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const BenefitPlanSelector({
    super.key,
    required this.plans,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    if (plans.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextStyle optionStyle = TextStyle(fontSize: 12, color: colors.ink);
    if (plans.length == 1) {
      return Text('計畫：${plans.first.optionLabel}', style: optionStyle);
    }

    final List<DropdownMenuItem<int>> items = [];
    for (int index = 0; index < plans.length; index++) {
      items.add(DropdownMenuItem<int>(
        value: index,
        child: Text(plans[index].optionLabel, style: optionStyle, overflow: TextOverflow.ellipsis),
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.acc),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedIndex,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: (int? index) {
            if (index != null) {
              onChanged(index);
            }
          },
        ),
      ),
    );
  }
}
