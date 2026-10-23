import 'package:flutter/material.dart';
import '../services/customer_stage_service.dart';
import '../services/insurance_product_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/customer_stage_summary_bar.dart';
import '../widgets/insurance_product_card.dart';
import '../widgets/product_compare_bar.dart';
import '../widgets/product_search_widgets.dart';
import 'policy_comparison_screen.dart';
import '../theme/app_theme.dart';

/// 數據戰情：上方是業務漏斗指標，下方是真實保險商品目錄（5-2b 起改讀 insurance_products）
class DataDashboardTab extends StatefulWidget {
  final Function(String menu)? onMenuChanged;
  // 從客戶保單點進來時帶的商品編號：打開後直接搜出這款並勾選
  final String? focusProductId;

  const DataDashboardTab({super.key, this.onMenuChanged, this.focusProductId});

  @override
  State<DataDashboardTab> createState() => _DataDashboardTabState();
}

class _DataDashboardTabState extends State<DataDashboardTab> {
  static const int _maximumCompareCount = 8;
  static const int _pageSize = 12;

  final InsuranceProductService _productService = InsuranceProductService();
  final CustomerStageService _stageService = CustomerStageService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;

  // 上方一行客戶摘要（保戶／跟進中／未開發，規則見 CustomerStage）
  CustomerStageSummary _stageSummary = const CustomerStageSummary(
    totalCustomers: 0,
    clientCount: 0,
    prospectCount: 0,
    leadCount: 0,
  );
  ProductCatalogSummary _catalogSummary = const ProductCatalogSummary(totalCount: 0, lastUpdatedAt: null);

  // 篩選條件：險種（null＝全部）、是否包含批註條款
  String? _activeInsuranceType;
  bool _includeEndorsements = false;

  // 搜尋結果與勾選比較的商品
  List<InsuranceProduct> _products = [];
  final List<InsuranceProduct> _selectedProducts = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _filteredCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, String> stageByCustomerId = await _stageService.fetchStageByCustomerId();
      final ProductCatalogSummary catalogSummary = await _productService.fetchCatalogSummary();
      if (mounted) {
        setState(() {
          _stageSummary = CustomerStageService.summarize(stageByCustomerId);
          _catalogSummary = catalogSummary;
        });
      }
      await _applyFocusProduct();
      await _searchProducts(resetPage: true);
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, '資料載入異常：$error', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 網址帶了商品編號：把搜尋框設成那款商品的名稱、清掉險種篩選，並先勾選起來（之後可直接比較）
  Future<void> _applyFocusProduct() async {
    final String productId = widget.focusProductId ?? '';
    if (productId.isEmpty) {
      return;
    }
    final InsuranceProduct? product = await _productService.fetchProductById(productId);
    if (!mounted) return;
    if (product == null) {
      CustomToast.show(context, '找不到這款商品的資料', ToastType.warning);
      return;
    }

    _searchController.text = product.productName;
    setState(() {
      _activeInsuranceType = null;
      // 批註條款預設不顯示，要帶出的剛好是批註條款時把開關打開
      _includeEndorsements = product.productKind == 'endorsement';
      if (!_selectedProducts.any((selected) => selected.id == product.id)) {
        _selectedProducts.add(product);
      }
    });
  }

  Future<void> _searchProducts({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }
    setState(() => _isSearching = true);

    final InsuranceProductSearchResult result = await _productService.searchProducts(
      query: _searchController.text,
      insuranceType: _activeInsuranceType,
      includeEndorsements: _includeEndorsements,
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (mounted) {
      setState(() {
        _products = result.products;
        _filteredCount = result.totalCount;
        _totalPages = result.totalPages;
        _isSearching = false;
      });
    }
  }

  void _changePage(int newPage) {
    setState(() => _currentPage = newPage);
    _searchProducts();
  }

  void _toggleProductSelection(InsuranceProduct product) {
    final int index = _selectedProducts.indexWhere((selected) => selected.id == product.id);
    if (index != -1) {
      setState(() => _selectedProducts.removeAt(index));
      return;
    }
    if (_selectedProducts.length >= _maximumCompareCount) {
      CustomToast.show(context, '最多同時比較 $_maximumCompareCount 款商品', ToastType.warning);
      return;
    }
    setState(() => _selectedProducts.add(product));
  }

  void _openComparisonScreen() {
    if (_selectedProducts.isEmpty) {
      CustomToast.show(context, '請先勾選要比較的商品', ToastType.warning);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => PolicyComparisonScreen(initialProducts: List.of(_selectedProducts)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget body = const Center(child: CircularProgressIndicator());
    if (!_isLoading) {
      body = RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerStageSummaryBar(summary: _stageSummary, onScanPressed: _showScanComingSoon),
              const SizedBox(height: 24),
              _buildSearchPanel(colors),
              const SizedBox(height: 18),
              _buildProductList(colors),
              const SizedBox(height: 16),
              if (_totalPages > 1) _buildPager(colors),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          body,
          if (_selectedProducts.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ProductCompareBar(
                selectedProducts: _selectedProducts,
                maximumCount: _maximumCompareCount,
                onClear: () => setState(() => _selectedProducts.clear()),
                onCompare: _openComparisonScreen,
              ),
            ),
        ],
      ),
    );
  }

  /// 掃描保單還沒做（第 5 階段 E），先佔位置（2026-10-23 沛沛選「先放即將推出」）
  void _showScanComingSoon() {
    CustomToast.show(context, '掃描保單功能即將推出', ToastType.warning);
  }

  Widget _buildSearchPanel(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品區標題（宋體，和上方「客戶概況」一致；掃描保單在客戶概況第四張卡片）
          Text('商品查詢', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
          const SizedBox(height: 12),
          _ProductSearchField(
            controller: _searchController,
            onSearch: () => _searchProducts(resetPage: true),
          ),
          const SizedBox(height: 12),
          CatalogCountLine(
            filteredCount: _filteredCount,
            catalogSummary: _catalogSummary,
          ),
          const SizedBox(height: 12),
          Text('險種：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.ink3)),
          const SizedBox(height: 6),
          InsuranceTypeFilter(
            activeInsuranceType: _activeInsuranceType,
            includeEndorsements: _includeEndorsements,
            onTypeSelected: (String? insuranceType) {
              setState(() => _activeInsuranceType = insuranceType);
              _searchProducts(resetPage: true);
            },
            onEndorsementsChanged: (bool include) {
              setState(() => _includeEndorsements = include);
              _searchProducts(resetPage: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(AppColors colors) {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: colors.ink3),
              const SizedBox(height: 12),
              Text('沒有符合條件的商品', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink)),
              const SizedBox(height: 4),
              Text('換個關鍵字或險種試試看', style: TextStyle(fontSize: 12, color: colors.ink3)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 寬螢幕 3 欄、平板 2 欄、手機 1 欄
        int columnCount = 1;
        if (constraints.maxWidth > 1000) {
          columnCount = 3;
        } else if (constraints.maxWidth > 650) {
          columnCount = 2;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 168,
          ),
          itemCount: _products.length,
          itemBuilder: (itemContext, index) {
            final InsuranceProduct product = _products[index];
            final bool isSelected = _selectedProducts.any((selected) => selected.id == product.id);
            return InsuranceProductCard(
              product: product,
              isSelected: isSelected,
              onToggleSelected: () => _toggleProductSelection(product),
            );
          },
        );
      },
    );
  }

  Widget _buildPager(AppColors colors) {
    VoidCallback? goPrevious;
    if (_currentPage > 1) {
      goPrevious = () => _changePage(_currentPage - 1);
    }
    VoidCallback? goNext;
    if (_currentPage < _totalPages) {
      goNext = () => _changePage(_currentPage + 1);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: goPrevious, icon: const Icon(Icons.chevron_left_rounded)),
        Text(
          '第 $_currentPage / $_totalPages 頁',
          style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
        ),
        IconButton(onPressed: goNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

/// 搜尋框＋搜尋按鈕
class _ProductSearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _ProductSearchField({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: '搜尋商品名稱、代碼、保險公司…',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded, size: 16),
          label: const Text('搜尋', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
        ),
      ],
    );
  }
}
