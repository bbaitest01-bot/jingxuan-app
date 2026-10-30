import 'package:flutter/material.dart';
import '../../services/app_settings.dart';
import 'customer_grid_view.dart';
import 'customer_list_view.dart';

/// 客戶列表區：載入中顯示骨架、沒有客戶顯示空白提示，否則依檢視模式顯示卡片或條列
class CustomerCollectionView extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final bool isLoading;
  final bool isListMode;
  final bool isWideScreen;
  final double screenWidth;
  final bool isSelectionMode;
  final Set<String> selectedCustomerIds;
  final CustomerCardActions actions;

  /// false 時列表直接出現、不播淡入動畫（顯示上次暫存的資料時用）
  final bool animateEntrance;

  const CustomerCollectionView({
    super.key,
    required this.customers,
    required this.isLoading,
    required this.isListMode,
    required this.isWideScreen,
    required this.screenWidth,
    required this.isSelectionMode,
    required this.selectedCustomerIds,
    required this.actions,
    required this.animateEntrance,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;

    if (isLoading) {
      if (isListMode) return const CustomerShimmerList();
      return CustomerShimmerGrid(isWideScreen: isWideScreen, screenWidth: screenWidth);
    }
    if (customers.isEmpty) {
      return CustomerEmptyState(isDark: isDark, primaryColor: primaryColor);
    }
    if (isListMode) {
      return CustomerListView(
        customers: customers,
        isWideScreen: isWideScreen,
        isSelectionMode: isSelectionMode,
        selectedCustomerIds: selectedCustomerIds,
        actions: actions,
        animateEntrance: animateEntrance,
      );
    }
    return CustomerGridView(
      customers: customers,
      isWideScreen: isWideScreen,
      screenWidth: screenWidth,
      isSelectionMode: isSelectionMode,
      selectedCustomerIds: selectedCustomerIds,
      actions: actions,
      animateEntrance: animateEntrance,
    );
  }
}
