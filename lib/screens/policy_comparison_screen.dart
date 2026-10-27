import 'package:flutter/material.dart';
import '../services/benefit_plan_service.dart';
import '../services/insurance_product_service.dart';
import '../widgets/benefit_plan_comparison.dart';
import '../widgets/custom_toast.dart';
import '../widgets/enroll_product_dialog.dart';
import '../widgets/insurance_product_card.dart';
import '../theme/app_theme.dart';

/// 比較表的一列：標題＋從商品取出要顯示的文字
class _ComparisonRow {
  final String label;
  final String Function(InsuranceProduct product) valueOf;

  const _ComparisonRow(this.label, this.valueOf);
}

/// 比較表的一個區塊（例如「基本資料」）
class _ComparisonSection {
  final String title;
  final List<_ComparisonRow> rows;

  const _ComparisonSection(this.title, this.rows);
}

/// 保單比較：2～8 款真實商品並排比較；只有 1 款時當作「商品資料」頁
///
/// 理賠限額（實支實付）讀 insurance_product_benefit_plans（D14，全景地圖 4-K），每欄可切換計畫；
/// 「全真醫療單據試算」「組合包聯合精算」按鈕保留但先停用，不用假數字計算（全景地圖 4-H ⑪）。
class PolicyComparisonScreen extends StatefulWidget {
  final List<InsuranceProduct> initialProducts;

  const PolicyComparisonScreen({super.key, required this.initialProducts});

  @override
  State<PolicyComparisonScreen> createState() => _PolicyComparisonScreenState();
}

class _PolicyComparisonScreenState extends State<PolicyComparisonScreen> {
  static final _ComparisonSection _basicSection = _ComparisonSection('基本資料', [
      _ComparisonRow('保險公司', (product) => product.companyName),
      _ComparisonRow('商品代碼', (product) => product.displayCode),
      _ComparisonRow('險種', (product) => product.insuranceTypeLabel),
      _ComparisonRow('主約／附約', (product) => product.productKindLabel),
      _ComparisonRow('官網分類', (product) => product.sourceCategory),
      _ComparisonRow('首次核准', (product) => formatApprovalDate(product.approvalDate)),
      _ComparisonRow('核准文號', (product) => product.approvalNumber ?? '—'),
    ]);

  late final List<InsuranceProduct> _products;
  bool _onlyShowDifferences = false;
  // 每款商品的實支實付計畫，以及目前選的是第幾個（沒有限額表的商品不在裡面）
  Map<String, List<InsuranceBenefitPlan>> _plansByProduct = {};
  final Map<String, int> _selectedPlanIndex = {};

  @override
  void initState() {
    super.initState();
    _products = List.of(widget.initialProducts);
    _loadBenefitPlans();
  }

  Future<void> _loadBenefitPlans() async {
    final List<String> productIds = [];
    for (final InsuranceProduct product in _products) {
      productIds.add(product.id);
    }
    final Map<String, List<InsuranceBenefitPlan>> plansByProduct =
        await BenefitPlanService().fetchPlansForProducts(productIds);
    if (!mounted) return;
    setState(() => _plansByProduct = plansByProduct);
  }

  /// 這款商品目前選的計畫；沒有限額表回傳 null
  InsuranceBenefitPlan? _selectedPlanOf(InsuranceProduct product) {
    final List<InsuranceBenefitPlan> plans = _plansByProduct[product.id] ?? const [];
    if (plans.isEmpty) {
      return null;
    }
    final int index = (_selectedPlanIndex[product.id] ?? 0).clamp(0, plans.length - 1);
    return plans[index];
  }

  /// 基本資料＋理賠限額兩個區塊；限額的值跟著每欄選的計畫變
  List<_ComparisonSection> _allSections() {
    final List<_ComparisonRow> benefitRows = [];
    for (final String label in benefitRowLabels) {
      benefitRows.add(_ComparisonRow(label, (product) => benefitRowText(label, _selectedPlanOf(product))));
    }
    return [_basicSection, _ComparisonSection('理賠限額（實支實付）', benefitRows)];
  }

  void _removeProduct(int index) {
    if (_products.length <= 1) {
      CustomToast.show(context, '比較表至少要保留 1 款商品', ToastType.warning);
      return;
    }
    setState(() => _products.removeAt(index));
  }

  /// 試算功能需要理賠限額資料，第二層比價資料做好前先停用
  void _showCalculatorNotReady() {
    CustomToast.show(context, '試算需要理賠限額資料，目前建置中', ToastType.warning);
  }

  /// 「只看差異」打開時，所有商品值都一樣的列就不顯示
  bool _isRowVisible(_ComparisonRow row) {
    // 只有一款商品時沒有差異可比，全部顯示
    if (!_onlyShowDifferences || _products.length < 2) {
      return true;
    }
    final Set<String> distinctValues = {};
    for (final InsuranceProduct product in _products) {
      distinctValues.add(row.valueOf(product));
    }
    return distinctValues.length > 1;
  }

  /// 依「只看差異」篩過後要顯示的區塊（整區都沒有差異就整區隱藏）
  List<_ComparisonSection> _visibleSections() {
    final List<_ComparisonSection> visibleSections = [];
    for (final _ComparisonSection section in _allSections()) {
      final List<_ComparisonRow> visibleRows = [];
      for (final _ComparisonRow row in section.rows) {
        if (_isRowVisible(row)) {
          visibleRows.add(row);
        }
      }
      if (visibleRows.isNotEmpty) {
        visibleSections.add(_ComparisonSection(section.title, visibleRows));
      }
    }
    return visibleSections;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<_ComparisonSection> sections = _visibleSections();

    final List<Widget> productColumns = [];
    for (int index = 0; index < _products.length; index++) {
      final InsuranceProduct product = _products[index];
      productColumns.add(_ProductComparisonColumn(
        product: product,
        sections: sections,
        plans: _plansByProduct[product.id] ?? const [],
        selectedPlanIndex: _selectedPlanIndex[product.id] ?? 0,
        onPlanChanged: (int planIndex) => setState(() => _selectedPlanIndex[product.id] = planIndex),
        onRemove: () => _removeProduct(index),
        onCalculatorPressed: _showCalculatorNotReady,
        canRemove: _products.length > 1,
      ));
    }

    // 一款商品＝商品資料頁；兩款以上才是並排比較
    final bool isComparing = _products.length >= 2;
    String title = '商品資料';
    if (isComparing) {
      title = '商品並排比較（${_products.length} 款）';
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
        ),
        actions: [
          if (isComparing)
            OutlinedButton.icon(
              onPressed: _showCalculatorNotReady,
              icon: const Icon(Icons.waterfall_chart_rounded, size: 15),
              label: const Text('組合包聯合精算（建置中）', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.ink3,
                side: BorderSide(color: colors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
            ),
          if (isComparing) ...[
            const SizedBox(width: 8),
            Text('只看差異', style: TextStyle(fontSize: 12, color: colors.ink, fontWeight: FontWeight.bold)),
            Switch(
              value: _onlyShowDifferences,
              activeThumbColor: colors.acc,
              onChanged: (bool value) => setState(() => _onlyShowDifferences = value),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: productColumns,
              ),
            ),
            const SizedBox(height: 12),
            Text(benefitAmountNotice, style: TextStyle(fontSize: 11, color: colors.ink3)),
          ],
        ),
      ),
    );
  }
}

/// 比較表中的一款商品（一直欄）
class _ProductComparisonColumn extends StatelessWidget {
  final InsuranceProduct product;
  final List<_ComparisonSection> sections;
  final List<InsuranceBenefitPlan> plans;
  final int selectedPlanIndex;
  final ValueChanged<int> onPlanChanged;
  final VoidCallback onRemove;
  final VoidCallback onCalculatorPressed;
  final bool canRemove;

  const _ProductComparisonColumn({
    required this.product,
    required this.sections,
    required this.plans,
    required this.selectedPlanIndex,
    required this.onPlanChanged,
    required this.onRemove,
    required this.onCalculatorPressed,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> sectionWidgets = [];
    for (final _ComparisonSection section in sections) {
      sectionWidgets.add(_SectionHeader(title: section.title));
      for (final _ComparisonRow row in section.rows) {
        sectionWidgets.add(_SpecRow(label: row.label, value: row.valueOf(product)));
      }
    }

    return Container(
      width: 295,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(product: product, onRemove: onRemove, canRemove: canRemove),
          if (plans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: BenefitPlanSelector(plans: plans, selectedIndex: selectedPlanIndex, onChanged: onPlanChanged),
            ),
          ...sectionWidgets,
          Divider(height: 1, color: colors.line),
          _ColumnActions(product: product, onCalculatorPressed: onCalculatorPressed),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final InsuranceProduct product;
  final VoidCallback onRemove;
  final bool canRemove;

  const _ColumnHeader({required this.product, required this.onRemove, required this.canRemove});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      color: colors.accSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductInfoChip(text: product.displayCode, isMono: true),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: colors.ink3),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                  tooltip: '移除此商品',
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(product.companyName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc)),
          const SizedBox(height: 2),
          Text(
            product.productName,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 下方三個按鈕：單據試算（建置中）、＋加到客戶、官方條款
class _ColumnActions extends StatelessWidget {
  final InsuranceProduct product;
  final VoidCallback onCalculatorPressed;

  const _ColumnActions({required this.product, required this.onCalculatorPressed});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onCalculatorPressed,
            icon: const Icon(Icons.health_and_safety_outlined, size: 15),
            label: const Text('全真醫療單據試算（建置中）', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink3,
              side: BorderSide(color: colors.line),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: buttonShape,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => showEnrollProductDialog(context, product),
            // 圖示是「＋」，按鈕整體讀起來就是「＋ 加到客戶」（D8）
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('加到客戶', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: buttonShape,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => openOfficialClause(context, product),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
            label: const Text('官方條款 PDF', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.line),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: buttonShape,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colors.surface2,
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.ink3)),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // 沒有資料（—）、不是實支實付、不分項目的格子用淡色，和真實數字區分
    Color valueColor = colors.ink;
    FontWeight valueWeight = FontWeight.bold;
    final bool isPlaceholder = value.startsWith('—') || value == notReimbursementText || value == notItemizedText;
    if (isPlaceholder) {
      valueColor = colors.ink3;
      valueWeight = FontWeight.normal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: TextStyle(fontSize: 11, color: colors.ink3))),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 11.5, fontWeight: valueWeight, color: valueColor)),
          ),
        ],
      ),
    );
  }
}
