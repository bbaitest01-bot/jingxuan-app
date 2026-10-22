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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
            '已選 ${selectedProducts.length}/$maximumCount 款商品',
            style: TextStyle(color: colors.onAcc, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedCodes.join('  '),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            label: const Text('開始比較', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
