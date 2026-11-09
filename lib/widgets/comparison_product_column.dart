import 'package:flutter/material.dart';
import '../services/benefit_item_service.dart';
import '../services/benefit_plan_service.dart';
import '../services/benefit_trial_calculator.dart';
import '../services/insurance_product_service.dart';
import '../services/scenario/claim_scenario.dart';
import '../theme/app_theme.dart';
import 'benefit_item_comparison.dart';
import 'benefit_plan_comparison.dart';
import 'benefit_trial_inputs.dart';
import 'comparison_column_parts.dart';
import 'comparison_table_rows.dart';
import 'scenario/no_benefit_notice.dart';
import 'scenario/scenario_result_card.dart';

/// 比較表的一列：標題＋從商品取出要顯示的文字
class ComparisonRow {
  final String label;
  final String Function(InsuranceProduct product) valueOf;
  // 給付項目的列：點格子可以看條款原文；其他列是 null
  final InsuranceBenefitItem? Function(InsuranceProduct product)? itemOf;
  // 點了要做別的事的列（例：資料來源打開官網）；其他列是 null
  final void Function(BuildContext context, InsuranceProduct product)? onTapOf;

  const ComparisonRow(this.label, this.valueOf, {this.itemOf, this.onTapOf});
}

/// 比較表的一個區塊（例如「基本資料」）
class ComparisonSection {
  final String title;
  final List<ComparisonRow> rows;

  const ComparisonSection(this.title, this.rows);
}

/// 比較表中的一款商品（一直欄）
class ProductComparisonColumn extends StatelessWidget {
  /// 一欄的寬度與欄跟欄的間距（上方滑軌的箭頭一次移「欄寬＋間距」）
  static const double columnWidth = 295;
  static const double columnGap = 16;

  final InsuranceProduct product;
  final List<ComparisonSection> sections;
  final List<InsuranceBenefitPlan> plans;
  final List<InsuranceBenefitItem> benefitItems;
  final ValueChanged<BenefitTrialInput> onTrialChanged;
  // 從比較清單打開時，試算欄要先填好的數字；一般比較是 null
  final BenefitTrialInput? initialTrialInput;
  final ClaimScenarioResult scenarioResult;
  final int copies;
  final ValueChanged<int> onCopiesChanged;
  final bool isBenefitDataLoaded;
  final int selectedPlanIndex;
  final ValueChanged<int> onPlanChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  const ProductComparisonColumn({
    super.key,
    required this.product,
    required this.sections,
    required this.plans,
    required this.benefitItems,
    required this.onTrialChanged,
    this.initialTrialInput,
    required this.scenarioResult,
    required this.copies,
    required this.onCopiesChanged,
    required this.isBenefitDataLoaded,
    required this.selectedPlanIndex,
    required this.onPlanChanged,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> sectionWidgets = [];
    for (final ComparisonSection section in sections) {
      sectionWidgets.add(ComparisonSectionHeader(title: section.title));
      for (final ComparisonRow row in section.rows) {
        VoidCallback? onTap;
        final InsuranceBenefitItem? item = row.itemOf?.call(product);
        if (item != null) {
          onTap = () => showBenefitItemSource(context, product, item);
        }
        final void Function(BuildContext context, InsuranceProduct product)? rowTap = row.onTapOf;
        if (rowTap != null) {
          onTap = () => rowTap(context, product);
        }
        sectionWidgets.add(ComparisonSpecRow(label: row.label, value: row.valueOf(product), onTap: onTap));
      }
    }

    return Container(
      width: columnWidth,
      margin: const EdgeInsets.only(right: columnGap),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComparisonColumnHeader(product: product, onRemove: onRemove, canRemove: canRemove),
          if (plans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: BenefitPlanSelector(plans: plans, selectedIndex: selectedPlanIndex, onChanged: onPlanChanged),
            ),
          // 有給付項目（定額型）的商品才有試算
          if (benefitItems.isNotEmpty)
            BenefitTrialPanel(
              fields: BenefitTrialCalculator.fieldsFor(benefitItems),
              currencyUnit: BenefitTrialCalculator.currencyUnitOf(product.productName),
              onChanged: onTrialChanged,
              initialInput: initialTrialInput,
            ),
          // 沒有給付項目也沒有限額表（豁免保費、批註…）：說明原因，不顯示情境結果
          if (isBenefitDataLoaded && plans.isEmpty && benefitItems.isEmpty)
            NoBenefitNotice(product: product)
          else
            // 情境試算的結果（放在試算下面：試算填的保額、日額會用到）
            ScenarioResultCard(
              result: scenarioResult,
              currencyUnit: BenefitTrialCalculator.currencyUnitOf(product.productName),
              copies: copies,
              onCopiesChanged: onCopiesChanged,
            ),
          ...sectionWidgets,
          Divider(height: 1, color: colors.line),
          ComparisonColumnActions(product: product),
        ],
      ),
    );
  }
}
