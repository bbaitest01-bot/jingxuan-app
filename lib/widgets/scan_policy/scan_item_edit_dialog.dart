import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/insurance_product_service.dart';
import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';

/// 修改或新增一個辨識出的商品；回傳修改後的商品，按取消回傳 null
///
/// 可以手動改名稱、主附約、計畫或保額、保費，也可以從商品目錄搜尋，選對正確的商品。
/// onDelete：修改時視窗左下角有「刪除這項」（2026-10-29 改版：刪除從清單每列移到這裡）
Future<ScannedPolicyItem?> showScanItemEditDialog(
  BuildContext context, {
  required ScannedPolicyItem item,
  required String? companyShortName,
  required bool isNewItem,
  VoidCallback? onDelete,
}) {
  return showDialog<ScannedPolicyItem>(
    context: context,
    builder: (BuildContext dialogContext) => _ScanItemEditDialog(
      item: item,
      companyShortName: companyShortName,
      isNewItem: isNewItem,
      onDelete: onDelete,
    ),
  );
}

class _ScanItemEditDialog extends StatefulWidget {
  final ScannedPolicyItem item;
  final String? companyShortName;
  final bool isNewItem;
  final VoidCallback? onDelete;

  const _ScanItemEditDialog({
    required this.item,
    required this.companyShortName,
    required this.isNewItem,
    this.onDelete,
  });

  @override
  State<_ScanItemEditDialog> createState() => _ScanItemEditDialogState();
}

class _ScanItemEditDialogState extends State<_ScanItemEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _planController;
  late final TextEditingController _premiumController;
  late final TextEditingController _searchController;
  String? _coverageRole;
  InsuranceProduct? _matchedProduct;
  List<InsuranceProduct> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDelayTimer;

  @override
  void initState() {
    super.initState();
    final ScannedPolicyItem item = widget.item;
    _nameController = TextEditingController(text: item.productName);
    _planController = TextEditingController(text: item.planOrAmount ?? '');
    _premiumController = TextEditingController(text: item.premium?.toString() ?? '');
    _coverageRole = item.coverageRole;
    _matchedProduct = item.matchedProduct;

    // 預設用「公司＋商品名稱」去搜尋目錄，方便直接挑
    final String companyKeyword = widget.companyShortName ?? '';
    final String nameKeyword = PolicyScanService.normalizeProductName(item.productName);
    _searchController = TextEditingController(text: '$companyKeyword $nameKeyword'.trim());
    if (_searchController.text.isNotEmpty) {
      _searchCatalog();
    }
  }

  @override
  void dispose() {
    _searchDelayTimer?.cancel();
    _nameController.dispose();
    _planController.dispose();
    _premiumController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 打字停 0.4 秒才搜尋，避免每打一個字就查一次資料庫
  void _onSearchTextChanged(String _) {
    _searchDelayTimer?.cancel();
    _searchDelayTimer = Timer(const Duration(milliseconds: 400), _searchCatalog);
  }

  Future<void> _searchCatalog() async {
    setState(() => _isSearching = true);
    final InsuranceProductSearchResult result = await InsuranceProductService().searchProducts(
      query: _searchController.text,
      pageSize: 6,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = result.products;
      _isSearching = false;
    });
  }

  void _chooseCatalogProduct(InsuranceProduct product) {
    setState(() {
      _matchedProduct = product;
      _nameController.text = product.productName;
      if (product.productKind == 'main' || product.productKind == 'rider') {
        _coverageRole = product.productKind;
      }
    });
  }

  void _submit() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    // 名稱被改成和目錄商品不同時，就不算對到目錄
    InsuranceProduct? matchedProduct = _matchedProduct;
    if (matchedProduct != null && matchedProduct.productName != name) {
      matchedProduct = null;
    }
    final String planText = _planController.text.trim();
    final String premiumDigits = _premiumController.text.replaceAll(RegExp(r'[^0-9]'), '');

    Navigator.pop(
      context,
      ScannedPolicyItem(
        productName: name,
        coverageRole: _coverageRole,
        planOrAmount: planText.isEmpty ? null : planText,
        premium: int.tryParse(premiumDigits),
        premiumCurrency: widget.item.premiumCurrency,
        matchedProduct: matchedProduct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(widget.isNewItem ? '補上商品' : '修改商品', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel(colors, '商品名稱'),
              TextField(controller: _nameController, decoration: const InputDecoration(isDense: true)),
              const SizedBox(height: 12),
              _buildFieldLabel(colors, '主約／附約'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'main', label: Text('主約')),
                  ButtonSegment<String>(value: 'rider', label: Text('附約')),
                ],
                selected: _coverageRole == null ? <String>{} : {_coverageRole!},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (Set<String> selected) {
                  setState(() => _coverageRole = selected.isEmpty ? null : selected.first);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildLabeledField(colors, '計畫或保額', _planController, '例：計畫三、50 萬元')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildLabeledField(colors, _premiumLabel(), _premiumController, '例：12350')),
                ],
              ),
              const SizedBox(height: 16),
              _buildCatalogSection(colors),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: colors.warn),
            child: const Text('刪除這項'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('確定'),
        ),
      ],
    );
  }

  /// 新臺幣顯示「保費（元）」，外幣顯示「保費（USD）」
  String _premiumLabel() {
    final String currency = widget.item.premiumCurrency ?? 'TWD';
    if (currency == 'TWD') {
      return '保費（元）';
    }
    return '保費（$currency）';
  }

  Widget _buildFieldLabel(AppColors colors, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink)),
    );
  }

  Widget _buildLabeledField(AppColors colors, String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(colors, label),
        TextField(controller: controller, decoration: InputDecoration(isDense: true, hintText: hint)),
      ],
    );
  }

  Widget _buildCatalogSection(AppColors colors) {
    final List<Widget> resultRows = [];
    for (final InsuranceProduct product in _searchResults) {
      resultRows.add(_CatalogChoiceRow(
        product: product,
        isSelected: _matchedProduct?.id == product.id,
        onTap: () => _chooseCatalogProduct(product),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('從商品目錄選擇（選了就算對到目錄）', style: TextStyle(fontSize: 12, color: colors.ink2)),
          const SizedBox(height: 6),
          TextField(
            controller: _searchController,
            onChanged: _onSearchTextChanged,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '輸入公司或商品關鍵字',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          if (_isSearching)
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
          else if (resultRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('目錄中找不到，可以直接用上面的名稱存入', style: TextStyle(fontSize: 12, color: colors.ink3)),
            )
          else
            ...resultRows,
        ],
      ),
    );
  }
}

class _CatalogChoiceRow extends StatelessWidget {
  final InsuranceProduct product;
  final bool isSelected;
  final VoidCallback onTap;

  const _CatalogChoiceRow({required this.product, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isSelected ? colors.acc : colors.ink3,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(product.productName, style: TextStyle(fontSize: 12, color: colors.ink)),
            ),
            const SizedBox(width: 6),
            Text(product.productKindLabel, style: TextStyle(fontSize: 11, color: colors.ink3)),
          ],
        ),
      ),
    );
  }
}
