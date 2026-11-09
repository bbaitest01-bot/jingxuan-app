import 'package:flutter/material.dart';
import '../main.dart' show isOfflineMode;
import '../models/saved_comparison.dart';
import '../services/benefit_item_service.dart';
import '../services/benefit_plan_service.dart';
import '../services/benefit_trial_calculator.dart';
import '../services/insurance_product_service.dart';
import '../services/saved_comparison_service.dart';
import '../services/scenario/claim_scenario.dart';
import '../services/scenario/claim_scenario_calculator.dart';
import '../widgets/benefit_item_comparison.dart';
import '../widgets/benefit_plan_comparison.dart';
import '../widgets/comparison_product_column.dart';
import '../widgets/comparison_scroll_bar.dart';
import '../widgets/custom_toast.dart';
import '../widgets/insurance_product_card.dart';
import '../widgets/saved_comparison/saved_comparison_save_panel.dart';
import '../widgets/saved_comparison/saved_comparison_update_panel.dart';
import '../widgets/scenario/scenario_input_panel.dart';
import '../theme/app_theme.dart';

/// 保單比較：2～8 款真實商品並排比較；只有 1 款時當作「商品資料」頁
///
/// 理賠限額（實支實付）讀 insurance_product_benefit_plans（D14，全景地圖 4-K），每欄可切換計畫；
/// 定額型商品的給付項目讀 insurance_product_benefit_items（第 5 階段 D 第 2 層），點格子看條款原文；
/// 舊設計的「全真醫療單據試算」「組合包聯合精算」一直停用，2026-11-04 拿掉（和保單健檢重疊，D26）。
/// 2026-11-07 加「情境試算」：最上面填情境（住院、身故、癌症…），每欄算「這個情境大約可以拿多少」。
class PolicyComparisonScreen extends StatefulWidget {
  final List<InsuranceProduct> initialProducts;
  // 從客戶的比較清單打開時才有：要還原哪一筆、是哪位客戶的（D36）
  final SavedComparison? savedComparison;
  final String? customerName;

  const PolicyComparisonScreen({
    super.key,
    required this.initialProducts,
    this.savedComparison,
    this.customerName,
  });

  @override
  State<PolicyComparisonScreen> createState() => _PolicyComparisonScreenState();
}

class _PolicyComparisonScreenState extends State<PolicyComparisonScreen> {
  static final ComparisonSection _basicSection = ComparisonSection('基本資料', [
    ComparisonRow('保險公司', (product) => product.companyName),
    ComparisonRow('商品代碼', (product) => product.displayCode),
    ComparisonRow('險種', (product) => product.insuranceTypeLabel),
    ComparisonRow('主約／附約', (product) => product.productKindLabel),
    ComparisonRow('官網分類', (product) => product.sourceCategory),
    ComparisonRow('首次核准', (product) => formatApprovalDate(product.approvalDate)),
    ComparisonRow('核准文號', (product) => product.approvalNumber ?? '—'),
    ComparisonRow('資料來源', productSourceLabel, onTapOf: openProductSource),
    ComparisonRow('官網最後確認', (product) => formatApprovalDate(product.lastSeenAt)),
  ]);

  late final List<InsuranceProduct> _products;
  bool _onlyShowDifferences = false;
  // 每款商品的實支實付計畫，以及目前選的是第幾個（沒有限額表的商品不在裡面）
  Map<String, List<InsuranceBenefitPlan>> _plansByProduct = {};
  final Map<String, int> _selectedPlanIndex = {};
  // 每款商品的給付項目（定額型：住院日額、手術、癌症、重大傷病、長照、意外）
  Map<String, List<InsuranceBenefitItem>> _itemsByProduct = {};
  // 每款商品的試算數字（業務員填的保額、年繳保費…），只在這次比較用
  final Map<String, BenefitTrialInput> _trialInputByProduct = {};
  // 情境試算：每款共用同一個情境；實支實付各自選買幾張
  ClaimScenarioInput _scenarioInput = const ClaimScenarioInput();
  final Map<String, int> _copiesByProduct = {};
  // 給付項目、限額表都讀完了（還沒讀完前不顯示「沒有給付項目」的說明，免得閃一下）
  bool _isItemsLoaded = false;
  bool _isPlansLoaded = false;
  // 比較表左右捲動的控制器：表格和上方滑軌共用，任一邊移動另一邊跟著動
  final ScrollController _columnScrollController = ScrollController();
  // 目前打開的是哪一筆比較；「另存新的」之後會換成新的那筆
  SavedComparison? _openedComparison;
  // 手機轉向等情況換排法時，存檔框填到一半的內容不會消失
  final GlobalKey _savePanelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _products = List.of(widget.initialProducts);
    _restoreSavedComparison();
    _loadBenefitPlans();
    _loadBenefitItems();
  }

  @override
  void dispose() {
    _columnScrollController.dispose();
    super.dispose();
  }

  /// 從比較清單打開時，放回當時填的情境、數字、張數（計畫要等限額表讀到才知道是第幾個）
  void _restoreSavedComparison() {
    final SavedComparison? comparison = widget.savedComparison;
    if (comparison == null) return;
    _openedComparison = comparison;
    _scenarioInput = comparison.scenario;
    for (final InsuranceProduct product in _products) {
      final SavedComparisonItem? item = comparison.itemFor(product.id);
      if (item == null) continue;
      _copiesByProduct[product.id] = item.copies;
      _trialInputByProduct[product.id] = item.toTrialInput(BenefitTrialCalculator.currencyUnitOf(product.productName));
    }
  }

  /// 存的是計畫代號，這裡換回「第幾個」；計畫已經不存在就用第一個，並提醒業務員
  void _restoreSelectedPlans(Map<String, List<InsuranceBenefitPlan>> plansByProduct) {
    final SavedComparison? comparison = widget.savedComparison;
    if (comparison == null) return;
    bool isAnyPlanMissing = false;
    for (final InsuranceProduct product in _products) {
      final String? planCode = comparison.itemFor(product.id)?.planCode;
      final List<InsuranceBenefitPlan> plans = plansByProduct[product.id] ?? const [];
      if (planCode == null || plans.isEmpty) continue;
      final int planIndex = plans.indexWhere((InsuranceBenefitPlan plan) => plan.planCode == planCode);
      if (planIndex < 0) {
        isAnyPlanMissing = true;
        continue;
      }
      _selectedPlanIndex[product.id] = planIndex;
    }
    if (isAnyPlanMissing) {
      CustomToast.show(context, '有商品原本選的計畫已不存在，已改用第一個計畫', ToastType.warning);
    }
  }

  Future<void> _loadBenefitItems() async {
    final List<String> productIds = [];
    for (final InsuranceProduct product in _products) {
      productIds.add(product.id);
    }
    final Map<String, List<InsuranceBenefitItem>> itemsByProduct =
        await BenefitItemService().fetchItemsForProducts(productIds);
    if (!mounted) return;
    setState(() {
      _itemsByProduct = itemsByProduct;
      _isItemsLoaded = true;
    });
  }

  List<InsuranceBenefitItem> _itemsOf(InsuranceProduct product) {
    return _itemsByProduct[product.id] ?? const [];
  }

  /// 這款商品的試算數字；還沒填時也要帶幣別（外幣保單的換算說明用美元…）
  BenefitTrialInput _trialInputOf(InsuranceProduct product) {
    final BenefitTrialInput? input = _trialInputByProduct[product.id];
    if (input != null) {
      return input;
    }
    return BenefitTrialInput(currencyUnit: BenefitTrialCalculator.currencyUnitOf(product.productName));
  }

  /// 「年繳保費」列：有填顯示金額，沒填顯示「—」
  String _annualPremiumText(InsuranceProduct product) {
    final int? annualPremium = _trialInputOf(product).annualPremium;
    if (annualPremium == null) {
      return '—';
    }
    return BenefitTrialCalculator.formatMoney(annualPremium.toDouble(), _trialInputOf(product).currencyUnit);
  }

  Future<void> _loadBenefitPlans() async {
    final List<String> productIds = [];
    for (final InsuranceProduct product in _products) {
      productIds.add(product.id);
    }
    final Map<String, List<InsuranceBenefitPlan>> plansByProduct =
        await BenefitPlanService().fetchPlansForProducts(productIds);
    if (!mounted) return;
    _restoreSelectedPlans(plansByProduct);
    setState(() {
      _plansByProduct = plansByProduct;
      _isPlansLoaded = true;
    });
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

  /// 目前畫面上每一款的選擇和數字，存到客戶時用（D36）
  List<SavedComparisonItem> _currentSavedItems() {
    final List<SavedComparisonItem> items = [];
    for (final InsuranceProduct product in _products) {
      final BenefitTrialInput trialInput = _trialInputOf(product);
      items.add(SavedComparisonItem(
        productId: product.id,
        planCode: _selectedPlanOf(product)?.planCode,
        copies: _copiesByProduct[product.id] ?? 1,
        coverageAmount: trialInput.coverageAmount,
        dailyAmount: trialInput.dailyAmount,
        units: trialInput.units,
        annualPremium: trialInput.annualPremium,
      ));
    }
    return items;
  }

  /// 基本資料＋理賠限額＋給付項目；限額的值跟著每欄選的計畫變。
  /// 比較的商品都沒有限額表（或都沒有給付項目）時，那一區不顯示
  List<ComparisonSection> _allSections() {
    final List<ComparisonSection> sections = [_basicSection];

    bool anyProductHasPlans = false;
    final List<List<InsuranceBenefitItem>> itemLists = [];
    for (final InsuranceProduct product in _products) {
      if ((_plansByProduct[product.id] ?? const []).isNotEmpty) {
        anyProductHasPlans = true;
      }
      itemLists.add(_itemsOf(product));
    }

    if (anyProductHasPlans) {
      final List<ComparisonRow> benefitRows = [];
      for (final String label in benefitRowLabels) {
        benefitRows.add(ComparisonRow(label, (product) => benefitRowText(label, _selectedPlanOf(product))));
      }
      sections.add(ComparisonSection('理賠限額（實支實付）', benefitRows));
    }

    final List<String> itemKeys = BenefitItemService.orderedItemKeys(itemLists);
    if (itemKeys.isNotEmpty) {
      final List<ComparisonRow> itemRows = [ComparisonRow('年繳保費（試算）', _annualPremiumText)];
      for (final String itemKey in itemKeys) {
        itemRows.add(ComparisonRow(
          itemKey,
          (product) => benefitItemCellText(_itemsOf(product), itemKey, _trialInputOf(product)),
          itemOf: (product) => BenefitItemService.findItem(_itemsOf(product), itemKey),
        ));
      }
      sections.add(ComparisonSection('給付項目（條款）', itemRows));
    }
    return sections;
  }

  void _removeProduct(int index) {
    if (_products.length <= 1) {
      CustomToast.show(context, '比較表至少要保留 1 款商品', ToastType.warning);
      return;
    }
    setState(() => _products.removeAt(index));
  }

  /// 試算功能需要理賠限額資料，第二層比價資料做好前先停用
  /// 「只看差異」打開時，所有商品值都一樣的列就不顯示
  bool _isRowVisible(ComparisonRow row) {
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
  List<ComparisonSection> _visibleSections() {
    final List<ComparisonSection> visibleSections = [];
    for (final ComparisonSection section in _allSections()) {
      final List<ComparisonRow> visibleRows = [];
      for (final ComparisonRow row in section.rows) {
        if (_isRowVisible(row)) {
          visibleRows.add(row);
        }
      }
      if (visibleRows.isNotEmpty) {
        visibleSections.add(ComparisonSection(section.title, visibleRows));
      }
    }
    return visibleSections;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<ComparisonSection> sections = _visibleSections();

    final List<Widget> productColumns = [];
    for (int index = 0; index < _products.length; index++) {
      final InsuranceProduct product = _products[index];
      productColumns.add(ProductComparisonColumn(
        // 移除某一款時，其他欄填的數字才不會跑到隔壁
        key: ValueKey<String>(product.id),
        product: product,
        sections: sections,
        plans: _plansByProduct[product.id] ?? const [],
        benefitItems: _itemsOf(product),
        onTrialChanged: (BenefitTrialInput input) => setState(() => _trialInputByProduct[product.id] = input),
        initialTrialInput: _trialInputByProduct[product.id],
        scenarioResult: ClaimScenarioCalculator.calculate(
          input: _scenarioInput,
          plan: _selectedPlanOf(product),
          items: _itemsOf(product),
          trialInput: _trialInputOf(product),
        ),
        copies: _copiesByProduct[product.id] ?? 1,
        isBenefitDataLoaded: _isItemsLoaded && _isPlansLoaded,
        onCopiesChanged: (int copies) => setState(() => _copiesByProduct[product.id] = copies),
        selectedPlanIndex: _selectedPlanIndex[product.id] ?? 0,
        onPlanChanged: (int planIndex) => setState(() => _selectedPlanIndex[product.id] = planIndex),
        onRemove: () => _removeProduct(index),
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
        // 2026-11-04 沛沛決定拿掉「組合包聯合精算」（和保單健檢重疊，D26），上方只留「只看差異」
        actions: [
          if (isComparing) ...[
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
      // 上方固定一列「第幾款／滑軌／左右箭頭」，商品放不下時才出現（手機不顯示）
      body: ComparisonScrollArea(
        controller: _columnScrollController,
        columnCount: _products.length,
        columnStep: ProductComparisonColumn.columnWidth + ProductComparisonColumn.columnGap,
        child: _buildComparisonBody(productColumns),
      ),
    );
  }

  /// 情境試算；線上模式且有 2 款以上時，旁邊多一個存到客戶的框
  Widget _buildScenarioArea() {
    final Widget scenarioPanel = ScenarioInputPanel(
      input: _scenarioInput,
      onChanged: (ClaimScenarioInput input) => setState(() => _scenarioInput = input),
    );
    if (isOfflineMode || _products.length < SavedComparisonService.minimumProductCount) {
      return scenarioPanel;
    }
    return ScenarioWithSavePanelLayout(scenarioPanel: scenarioPanel, savePanel: _buildSavePanel());
  }

  /// 打開舊比較時是「更新這筆／另存新的」，一般比較是選客戶存新的
  Widget _buildSavePanel() {
    final SavedComparison? openedComparison = _openedComparison;
    if (openedComparison == null) {
      return SavedComparisonSavePanel(
        key: _savePanelKey,
        currentScenario: () => _scenarioInput,
        currentItems: _currentSavedItems,
      );
    }
    return SavedComparisonUpdatePanel(
      key: _savePanelKey,
      comparison: openedComparison,
      customerName: widget.customerName ?? '',
      currentScenario: () => _scenarioInput,
      currentItems: _currentSavedItems,
      onSavedAsNew: (SavedComparison newComparison) => setState(() => _openedComparison = newComparison),
    );
  }

  Widget _buildComparisonBody(List<Widget> productColumns) {
    final AppColors colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScenarioArea(),
          const SizedBox(height: 14),
          SingleChildScrollView(
            controller: _columnScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: productColumns,
            ),
          ),
          const SizedBox(height: 12),
          Text(benefitAmountNotice, style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 4),
          Text(benefitItemNotice, style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 4),
          Text(productDataSourceNotice, style: TextStyle(fontSize: 11, color: colors.ink3)),
        ],
      ),
    );
  }
}
