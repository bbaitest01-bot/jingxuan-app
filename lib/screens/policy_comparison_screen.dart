import 'package:flutter/material.dart';
import '../services/insurance_product_service.dart';
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

/// 第二層比價資料還沒做好時，限額欄位一律顯示這段文字（2026-10-23 沛沛選 B）
const String _notReadyText = '比價欄位建置中';

/// 保單比較：2～8 款真實商品並排比較；只有 1 款時當作「商品資料」頁
///
/// 理賠限額（病房、手術、雜費、2-2-7、收據）是第二層比價資料，目前顯示「建置中」；
/// 「全真醫療單據試算」「組合包聯合精算」按鈕保留但先停用，不用假數字計算（全景地圖 4-H ⑪）。
class PolicyComparisonScreen extends StatefulWidget {
  final List<InsuranceProduct> initialProducts;

  const PolicyComparisonScreen({super.key, required this.initialProducts});

  @override
  State<PolicyComparisonScreen> createState() => _PolicyComparisonScreenState();
}

class _PolicyComparisonScreenState extends State<PolicyComparisonScreen> {
  static final List<_ComparisonSection> _sections = [
    _ComparisonSection('基本資料', [
      _ComparisonRow('保險公司', (product) => product.companyName),
      _ComparisonRow('商品代碼', (product) => product.displayCode),
      _ComparisonRow('險種', (product) => product.insuranceTypeLabel),
      _ComparisonRow('主約／附約', (product) => product.productKindLabel),
      _ComparisonRow('官網分類', (product) => product.sourceCategory),
      _ComparisonRow('首次核准', (product) => formatApprovalDate(product.approvalDate)),
      _ComparisonRow('核准文號', (product) => product.approvalNumber ?? '—'),
    ]),
    _ComparisonSection('理賠限額與條款細節', [
      _ComparisonRow('病房費用', (product) => _notReadyText),
      _ComparisonRow('住院／門診手術', (product) => _notReadyText),
      _ComparisonRow('醫療雜費', (product) => _notReadyText),
      _ComparisonRow('健保 2-2-7 限制', (product) => _notReadyText),
      _ComparisonRow('收據規定', (product) => _notReadyText),
    ]),
  ];

  late final List<InsuranceProduct> _products;
  bool _onlyShowDifferences = false;

  @override
  void initState() {
    super.initState();
    _products = List.of(widget.initialProducts);
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
    for (final _ComparisonSection section in _sections) {
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
      productColumns.add(_ProductComparisonColumn(
        product: _products[index],
        sections: sections,
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: productColumns,
          ),
        ),
      ),
    );
  }
}

/// 比較表中的一款商品（一直欄）
class _ProductComparisonColumn extends StatelessWidget {
  final InsuranceProduct product;
  final List<_ComparisonSection> sections;
  final VoidCallback onRemove;
  final VoidCallback onCalculatorPressed;
  final bool canRemove;

  const _ProductComparisonColumn({
    required this.product,
    required this.sections,
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
    // 建置中的欄位用淡色，和真實資料區分
    Color valueColor = colors.ink;
    FontWeight valueWeight = FontWeight.bold;
    if (value == _notReadyText) {
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
