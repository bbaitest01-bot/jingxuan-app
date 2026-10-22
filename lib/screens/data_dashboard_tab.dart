import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/customer_policy_service.dart';
import '../services/insurance_product_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/dashboard_funnel_card.dart';
import '../widgets/insurance_product_card.dart';
import '../widgets/product_compare_bar.dart';
import 'policy_comparison_screen.dart';
import '../theme/app_theme.dart';

/// 數據戰情：上方是業務漏斗指標，下方是真實保險商品目錄（5-2b 起改讀 insurance_products）
class DataDashboardTab extends StatefulWidget {
  final Function(String menu)? onMenuChanged;

  const DataDashboardTab({super.key, this.onMenuChanged});

  @override
  State<DataDashboardTab> createState() => _DataDashboardTabState();
}

class _DataDashboardTabState extends State<DataDashboardTab> {
  static const int _maximumCompareCount = 8;
  static const int _pageSize = 12;

  final InsuranceProductService _productService = InsuranceProductService();
  final CustomerPolicyService _customerPolicyService = CustomerPolicyService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;

  CustomerFunnelSummary _funnelSummary = CustomerFunnelSummary(
    totalCustomers: 0,
    leadsCount: 0,
    prospectsCount: 0,
    clientsCount: 0,
    monthlyVisitsCompleted: 0,
    monthlyVisitsTotal: 0,
    activeProjectsCount: 0,
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
      final CustomerFunnelSummary funnel = await _customerPolicyService.fetchRealSalesFunnelMetrics();
      final ProductCatalogSummary catalogSummary = await _productService.fetchCatalogSummary();
      if (mounted) {
        setState(() {
          _funnelSummary = funnel;
          _catalogSummary = catalogSummary;
        });
      }
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
              _buildFunnelRow(colors),
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

  Widget _buildFunnelRow(AppColors colors) {
    final int visitRatePercent = (_funnelSummary.monthlyVisitRate * 100).toInt();
    return Row(
      children: [
        Expanded(
          child: DashboardFunnelCard(
            title: '名下客戶總量',
            mainValue: '${_funnelSummary.totalCustomers} 位',
            subtitle: '保戶 ${_funnelSummary.clientsCount}｜跟進 ${_funnelSummary.prospectsCount}｜未開發 ${_funnelSummary.leadsCount}',
            icon: Icons.people_alt_rounded,
            color: colors.acc,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DashboardFunnelCard(
            title: '本月拜訪戰況',
            mainValue: '${_funnelSummary.monthlyVisitsCompleted} / ${_funnelSummary.monthlyVisitsTotal} 次',
            subtitle: '達成率 $visitRatePercent%',
            icon: Icons.event_available_rounded,
            color: colors.ok,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DashboardFunnelCard(
            title: '推動中拜訪專案',
            mainValue: '${_funnelSummary.activeProjectsCount} 個專案',
            subtitle: '進行中的拜訪專案',
            icon: Icons.assignment_turned_in_rounded,
            color: colors.warn,
          ),
        ),
      ],
    );
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
          _ProductSearchField(
            controller: _searchController,
            onSearch: () => _searchProducts(resetPage: true),
          ),
          const SizedBox(height: 12),
          _CatalogCountLine(
            filteredCount: _filteredCount,
            catalogSummary: _catalogSummary,
          ),
          const SizedBox(height: 12),
          Text('險種：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.ink3)),
          const SizedBox(height: 6),
          _InsuranceTypeFilter(
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

/// 「找到 N 款」與資料來源、更新日期
class _CatalogCountLine extends StatelessWidget {
  final int filteredCount;
  final ProductCatalogSummary catalogSummary;

  const _CatalogCountLine({required this.filteredCount, required this.catalogSummary});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final NumberFormat numberFormat = NumberFormat('#,###');
    String updatedText = '尚未抓取';
    if (catalogSummary.lastUpdatedAt != null) {
      updatedText = DateFormat('yyyy/MM/dd').format(catalogSummary.lastUpdatedAt!);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '找到 ${numberFormat.format(filteredCount)} 款（全部 ${numberFormat.format(catalogSummary.totalCount)} 款）',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc),
        ),
        Text(
          '資料來源：國泰、富邦、南山官網資訊公開｜更新 $updatedText',
          style: TextStyle(fontSize: 11, color: colors.ink3),
        ),
      ],
    );
  }
}

/// 險種篩選（全部＋各險種）與「含批註條款」開關
class _InsuranceTypeFilter extends StatelessWidget {
  final String? activeInsuranceType;
  final bool includeEndorsements;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<bool> onEndorsementsChanged;

  const _InsuranceTypeFilter({
    required this.activeInsuranceType,
    required this.includeEndorsements,
    required this.onTypeSelected,
    required this.onEndorsementsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> chips = [_buildTypeChip(colors, null, '全部')];
    InsuranceProductService.insuranceTypeLabels.forEach((String insuranceType, String label) {
      chips.add(_buildTypeChip(colors, insuranceType, label));
    });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('含批註條款', style: TextStyle(fontSize: 11)),
          tooltip: '批註條款是附加在商品上的修改說明，不能單獨購買',
          selected: includeEndorsements,
          onSelected: onEndorsementsChanged,
        ),
      ],
    );
  }

  Widget _buildTypeChip(AppColors colors, String? insuranceType, String label) {
    final bool isSelected = activeInsuranceType == insuranceType;
    Color labelColor = colors.ink;
    if (isSelected) {
      labelColor = colors.onAcc;
    }
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: colors.acc,
      labelStyle: TextStyle(color: labelColor),
      onSelected: (_) => onTypeSelected(insuranceType),
    );
  }
}
