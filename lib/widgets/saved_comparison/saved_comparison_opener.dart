import 'package:flutter/material.dart';

import '../../models/saved_comparison.dart';
import '../../screens/policy_comparison_screen.dart';
import '../../services/insurance_product_service.dart';
import '../custom_toast.dart';

/// 依存的商品編號讀回商品，順序和存檔時一樣；找不到的商品略過
Future<List<InsuranceProduct>> loadProductsOfComparison(SavedComparison comparison) async {
  final List<Future<InsuranceProduct?>> productRequests = [];
  for (final SavedComparisonItem item in comparison.items) {
    productRequests.add(InsuranceProductService().fetchProductById(item.productId));
  }
  final List<InsuranceProduct?> results = await Future.wait(productRequests);
  final List<InsuranceProduct> products = [];
  for (final InsuranceProduct? product in results) {
    if (product != null) {
      products.add(product);
    }
  }
  return products;
}

/// 從客戶的比較清單打開一筆比較（D36）
Future<void> openSavedComparison(BuildContext context, SavedComparison comparison, String customerName) async {
  final List<InsuranceProduct> products = await loadProductsOfComparison(comparison);
  if (!context.mounted) return;
  if (products.isEmpty) {
    CustomToast.show(context, '這筆比較的商品都找不到了', ToastType.error);
    return;
  }
  final int missingCount = comparison.items.length - products.length;
  if (missingCount > 0) {
    CustomToast.show(context, '有 $missingCount 款商品找不到，已略過', ToastType.warning);
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext routeContext) => PolicyComparisonScreen(
        initialProducts: products,
        savedComparison: comparison,
        customerName: customerName,
      ),
    ),
  );
}
