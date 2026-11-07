import '../benefit_item_service.dart';
import '../benefit_plan_service.dart';
import '../benefit_trial_calculator.dart';
import 'claim_scenario.dart';
import 'formula_amount.dart';
import 'scenario_item_matcher.dart';

/// 情境試算：一款商品在這個情境大約可以拿多少
///
/// - 實支實付（有限額表）：花的錢和上限比，取小的；手術含不含在醫療費用、自負額、每次住院總上限都照限額表
/// - 其他商品（給付項目）：用名稱判斷這一項屬不屬於這個情境，再把算法套上試算填的保額／日額／單位
/// 算不出來的項目不猜，列在 notCounted
class ClaimScenarioCalculator {
  static ClaimScenarioResult calculate({
    required ClaimScenarioInput input,
    required InsuranceBenefitPlan? plan,
    required List<InsuranceBenefitItem> items,
    required BenefitTrialInput trialInput,
  }) {
    if (plan == null && items.isEmpty) {
      return const ClaimScenarioResult(emptyReason: '這款沒有整理好的給付項目（例如豁免保費、批註條款，本身不給付保險金）');
    }
    final List<ClaimScenarioLine> lines = [];
    final List<String> notCounted = [];
    bool isMinimum = false;

    // 實支實付只在住院情境算
    final bool isReimbursement = plan != null && input.type == ClaimScenarioType.hospital;
    if (isReimbursement) {
      lines.addAll(reimbursementLines(plan, input));
    }

    for (final InsuranceBenefitItem item in items) {
      final ScenarioItemUse use = ScenarioItemMatcher.useOf(item.itemName, item.formula, input);
      if (!use.isIncluded) continue;
      final String? conditionNote = use.conditionNote;
      if (conditionNote != null) {
        notCounted.add('${item.itemName}：$conditionNote');
        continue;
      }
      final FormulaAmount amount = FormulaAmountCalculator.calculate(
        item.formula,
        trialInput,
        disabilityRatio: use.disabilityRatio,
      );
      final int? value = amount.amount;
      if (value == null) {
        notCounted.add('${item.itemName}：${amount.note ?? '算不出來，請看條款原文'}');
        continue;
      }
      if (amount.isMinimum) isMinimum = true;
      lines.add(_itemLine(item.itemName, value, use, amount, trialInput.currencyUnit));
    }

    // 重大疾病：同一次生病通常只符合其中一張疾病清單（重大疾病、特定傷病、重大傷病…），
    // 只算最高的那一項，其他列在「沒加進去」（2026-11-07 抽查：三項加起來會多算）
    if (input.type == ClaimScenarioType.criticalIllness && lines.length > 1) {
      _keepHighestLine(lines, notCounted, trialInput.currencyUnit);
    }

    if (lines.isEmpty && notCounted.isEmpty) {
      return ClaimScenarioResult(emptyReason: '這款在「${ClaimScenarioType.label(input.type)}」情境不給付');
    }
    return ClaimScenarioResult(
      lines: lines,
      notCounted: notCounted,
      isMinimum: isMinimum,
      canBuyMultipleCopies: isReimbursement,
    );
  }

  /// 給付項目的一行：按天的寫「住院醫療保險金（2,000 元 × 5 天）」
  static ClaimScenarioLine _itemLine(String name, int value, ScenarioItemUse use, FormulaAmount amount, String currencyUnit) {
    // 按天、按月的項目，規則那邊已經給了天數／月數；一次給的是 1
    final int multiplier = use.multiplier;
    String label = name;
    if (multiplier > 1) {
      final String unitAmount = BenefitTrialCalculator.formatMoney(value.toDouble(), currencyUnit);
      label = '$name（$unitAmount × $multiplier ${use.multiplierUnit}）';
    }
    final List<String> notes = [];
    final String? lineNote = use.lineNote;
    final String? amountNote = amount.note;
    if (lineNote != null) notes.add(lineNote);
    if (amountNote != null) notes.add(amountNote);
    return ClaimScenarioLine(label, value * multiplier, note: notes.isEmpty ? null : notes.join('，'));
  }

  static void _keepHighestLine(List<ClaimScenarioLine> lines, List<String> notCounted, String currencyUnit) {
    ClaimScenarioLine highest = lines.first;
    for (final ClaimScenarioLine line in lines) {
      if (line.amount > highest.amount) highest = line;
    }
    for (final ClaimScenarioLine line in lines) {
      if (identical(line, highest)) continue;
      final String amountText = BenefitTrialCalculator.formatMoney(line.amount.toDouble(), currencyUnit);
      notCounted.add('${line.label}（$amountText）：屬於另一張疾病清單，同一次生病通常只符合其中一項');
    }
    lines
      ..clear()
      ..add(highest);
  }

  /// 實支實付（看收據報帳）：每一項「花的錢」和「上限」取小的
  static List<ClaimScenarioLine> reimbursementLines(InsuranceBenefitPlan plan, ClaimScenarioInput input) {
    final int days = input.hospitalDays;
    final int roomSpent = input.roomDifferencePerDay * days;

    // 總額型：不分項目，全部加起來和「每次住院總上限」比
    if (plan.isTotalType) {
      final int totalSpent = roomSpent + input.medicalExpense + input.surgeryExpense;
      final int deductible = (plan.hospitalExpenseDeductible ?? 0) + (plan.roomDeductible ?? 0);
      final int afterDeductible = _atLeastZero(totalSpent - deductible);
      final int? totalLimit = plan.perAdmissionTotalLimit;
      int paid = afterDeductible;
      if (totalLimit != null && paid > totalLimit) paid = totalLimit;
      return [ClaimScenarioLine('總額型實支實付（每次住院上限內）', paid, note: deductible > 0 ? '已扣自負額' : null)];
    }

    final List<ClaimScenarioLine> lines = [];
    // 病房：每天差額和每日上限取小的 × 天數（自負額型再扣自負額）
    final int? roomLimit = plan.roomDailyLimit;
    if (roomLimit != null && roomSpent > 0) {
      final int perDay = input.roomDifferencePerDay < roomLimit ? input.roomDifferencePerDay : roomLimit;
      final int roomPaid = _atLeastZero(perDay * days - (plan.roomDeductible ?? 0));
      lines.add(ClaimScenarioLine('病房 ${_number(perDay)} × $days 天', roomPaid));
    }

    // 醫療費用：手術含在裡面的計畫，手術費一起算進這個上限
    final int? expenseLimit = plan.hospitalExpenseLimit;
    final bool surgeryInExpense = plan.hospitalExpenseIncludesSurgery;
    int expenseSpent = input.medicalExpense;
    if (surgeryInExpense) expenseSpent += input.surgeryExpense;
    if (expenseLimit != null && expenseSpent > 0) {
      final int afterDeductible = _atLeastZero(expenseSpent - (plan.hospitalExpenseDeductible ?? 0));
      final int expensePaid = afterDeductible < expenseLimit ? afterDeductible : expenseLimit;
      String label = '住院醫療費用（上限 ${_tenThousands(expenseLimit)}）';
      if (surgeryInExpense && input.hasSurgery) label = '醫療＋手術費用（共用上限 ${_tenThousands(expenseLimit)}）';
      String? note;
      if ((plan.hospitalExpenseDeductible ?? 0) > 0) note = '已扣自負額 ${_number(plan.hospitalExpenseDeductible ?? 0)}';
      lines.add(ClaimScenarioLine(label, expensePaid, note: note));
    }

    // 手術：沒含在醫療費用裡、有自己的上限
    final int? surgeryLimit = plan.surgeryLimit;
    if (!surgeryInExpense && input.hasSurgery && surgeryLimit != null) {
      final int surgeryPaid = input.surgeryExpense < surgeryLimit ? input.surgeryExpense : surgeryLimit;
      lines.add(ClaimScenarioLine('手術（另外的上限 ${_tenThousands(surgeryLimit)}）', surgeryPaid));
    }

    // 每次住院總上限：加起來超過就扣回
    final int? totalLimit = plan.perAdmissionTotalLimit;
    int sum = 0;
    for (final ClaimScenarioLine line in lines) {
      sum += line.amount;
    }
    if (totalLimit != null && sum > totalLimit) {
      lines.add(ClaimScenarioLine('超過每次住院總上限 ${_tenThousands(totalLimit)}，扣回', totalLimit - sum));
    }
    return lines;
  }

  static int _atLeastZero(int value) => value < 0 ? 0 : value;

  static String _number(int value) => InsuranceBenefitPlan.formatAmount(value);

  static String _tenThousands(int value) => InsuranceBenefitPlan.formatTenThousands(value);
}
