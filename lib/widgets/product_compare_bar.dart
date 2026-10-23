import 'package:flutter/material.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';

/// 數據戰情底部的浮動列：顯示已選幾款、清除、開始比較
class ProductCompareBar extends StatelessWidget {
  final List<InsuranceProduct> selectedProducts;
  final int maximumCount;
  final VoidCallback onClear;
  final VoidCallback onCompare;

  const ProductCompareBar({
    super.key,
    required this.selectedProducts,
    required this.maximumCount,
    required this.onClear,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> selectedCodes = [];
    for (final InsuranceProduct product in selectedProducts) {
      selectedCodes.add(product.displayCode);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 手機寬度（D-09）：不顯示代碼、文字縮短，避免按鈕和文字擠在一起
        final bool isNarrow = constraints.maxWidth < 520;
        return _buildBar(colors, selectedCodes, isNarrow);
      },
    );
  }

  Widget _buildBar(AppColors colors, List<String> selectedCodes, bool isNarrow) {
    String countText = '已選 ${selectedProducts.length}/$maximumCount 款商品';
    String compareText = '開始比較';
    if (isNarrow) {
      countText = '已選 ${selectedProducts.length} 款';
      compareText = '比較';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.acc,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.onAcc, size: 20),
          const SizedBox(width: 8),
          Text(
            countText,
            style: TextStyle(color: colors.onAcc, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isNarrow ? '' : selectedCodes.join('  '),
              style: AppTextStyles.mono(fontSize: 11, color: colors.onAcc.withValues(alpha: 0.75)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text('清除', style: TextStyle(color: colors.onAcc.withValues(alpha: 0.75), fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onCompare,
            icon: const Icon(Icons.compare_arrows_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.onAcc,
              foregroundColor: colors.acc,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            label: Text(compareText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
