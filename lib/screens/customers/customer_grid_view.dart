import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';
import '../../widgets/animations.dart';
import 'customer_shimmers.dart';
import 'customer_card.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tour_target.dart';

/// 客戶卡片／清單上的按鈕要做的事，由外框（CustomerManagementTab）提供
class CustomerCardActions {
  final void Function(Map<String, dynamic> customer) onEdit;
  final void Function(Map<String, dynamic> customer) onDelete;
  /// 打開側邊欄；卡片模式會帶卡片在畫面上的位置，讓卡片飛到左邊
  final void Function(Map<String, dynamic> customer, {Rect? originRect}) onZoom;
  final void Function(Map<String, dynamic> customer) onManageRelationships;

  /// 多選模式下勾選或取消某位客戶：[selected] 為 true 代表選取
  final void Function(String customerId, bool selected) onSelectionChanged;

  const CustomerCardActions({
    required this.onEdit,
    required this.onDelete,
    required this.onZoom,
    required this.onManageRelationships,
    required this.onSelectionChanged,
  });
}

/// 卡片模式：依螢幕寬度決定一列幾張卡片；點卡片打開側邊欄，多選模式下點卡片是勾選
class CustomerGridView extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final bool isWideScreen;
  final double screenWidth;
  final bool isSelectionMode;
  final Set<String> selectedCustomerIds;
  final CustomerCardActions actions;

  /// false 時卡片直接出現、不播淡入動畫
  final bool animateEntrance;

  const CustomerGridView({
    super.key,
    required this.customers,
    required this.isWideScreen,
    required this.screenWidth,
    required this.isSelectionMode,
    required this.selectedCustomerIds,
    required this.actions,
    this.animateEntrance = true,
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = 1;
    double childAspectRatio = 2.0;

    if (isWideScreen) {
      if (screenWidth > 1200) {
        crossAxisCount = 3;
        // 卡片 C（2026-10-30）：多兩行摘要、拿掉信箱，比原本稍矮一點也不擠
        childAspectRatio = 1.75;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 1.5;
      }
    } else {
      childAspectRatio = 1.65;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        final id = customer['id'].toString();
        final isSelected = selectedCustomerIds.contains(id);

        Widget cardWidget = HoverAnimatedCard(
          child: CustomerCard(
            customer: customer,
            onOpen: (Rect cardRect) => actions.onZoom(customer, originRect: cardRect),
          ),
        );
        // 新手導覽第 5 步亮第一張卡片，並記下客戶編號給第 6 步打開
        if (index == 0) cardWidget = TourTarget(id: 'customers.first', payload: id, child: cardWidget);

        if (isSelectionMode) {
          cardWidget = Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? context.appColors.acc : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: IgnorePointer(
                  child: cardWidget,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    // 多選勾選圈：選中主題色、沒選白底灰框
                    color: isSelected ? context.appColors.acc : context.appColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? context.appColors.acc : context.appColors.line, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isSelected ? Icons.check : Icons.circle_outlined,
                      size: 16,
                      color: isSelected ? context.appColors.onAcc : context.appColors.ink3,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // 已選就取消、沒選就選取
                    actions.onSelectionChanged(id, !selectedCustomerIds.contains(id));
                  },
                ),
              ),
            ],
          );
        }

        return StaggeredFadeIn(
          index: index,
          animate: animateEntrance,
          child: cardWidget,
        );
      },
    );
  }
}

/// 3D 卡片模式的載入中骨架
class CustomerShimmerGrid extends StatelessWidget {
  final bool isWideScreen;
  final double screenWidth;

  const CustomerShimmerGrid({super.key, required this.isWideScreen, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = 1;
    double childAspectRatio = 2.0;

    if (isWideScreen) {
      if (screenWidth > 1200) {
        crossAxisCount = 3;
        // 卡片 C（2026-10-30）：多兩行摘要、拿掉信箱，比原本稍矮一點也不擠
        childAspectRatio = 1.75;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 1.5;
      }
    } else {
      childAspectRatio = 1.8;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const CustomerCardShimmer();
      },
    );
  }
}

/// 沒有任何客戶（或搜尋不到）時的空白提示
class CustomerEmptyState extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;

  const CustomerEmptyState({super.key, required this.isDark, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n('customer_empty_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appColors.ink2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n('customer_empty_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
