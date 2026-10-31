import 'package:flutter/material.dart';
import '../../widgets/customer_card_flight.dart';
import '../../widgets/customer_detail_side_sheet.dart';
import 'customer_card.dart';

/// 客戶管理打開側邊欄（2026-10-30 從 customer_management_tab.dart 拆出）
///
/// 卡片模式有 [originRect] 時，同一張卡片會飛到左邊中間；
/// 回傳的 Future 等卡片飛回原位（約 0.38 秒）才完成，呼叫的地方再把原本那張卡片顯示回來，避免同時出現兩張
Future<void> openCustomerDetail(
  BuildContext context, {
  required Map<String, dynamic> customer,
  required void Function(Map<String, dynamic> updated) onCustomerUpdated,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onManageRelationships,
  Rect? originRect,
}) async {
  // 這一頁（[context]）離畫面四邊的距離，左邊＝選單寬度：卡片停在這塊扣掉側邊欄後的正中間，視窗變了也跟著算
  EdgeInsets contentPadding = EdgeInsets.zero;
  final RenderObject? pageBox = context.findRenderObject();
  if (pageBox is RenderBox && pageBox.hasSize) {
    final Rect page = pageBox.localToGlobal(Offset.zero) & pageBox.size;
    final Size screen = MediaQuery.sizeOf(context);
    contentPadding = EdgeInsets.fromLTRB(page.left, page.top, screen.width - page.right, screen.height - page.bottom);
  }
  final String customerId = customer['id'].toString();
  // 列表裡那張卡片飛走時先藏起來；左邊放不下卡片時不飛，列表那張照常顯示
  void showFlyingCard(bool fits) => CustomerCard.flyingCustomerId.value = fits ? customerId : null;
  Widget? flyingCard;
  final Rect? cardRect = originRect;
  if (cardRect != null) {
    flyingCard = CustomerCard(customer: customer, onOpen: (_) {}, hideWhenFlying: false, showExtraDetails: true);
    showFlyingCard(CustomerCardFlight.fitsLanding(
      MediaQuery.sizeOf(context),
      cardRect.size,
      CustomerDetailSideSheet.desktopSheetWidth,
      contentPadding,
    ));
  }
  await CustomerDetailSideSheet.show(
    context,
    customer: customer,
    originRect: originRect,
    flyingCard: flyingCard,
    contentPadding: contentPadding,
    // 飛回去時找列表裡那張卡片現在的位置（視窗大小可能變了）
    currentOriginRect: () => CustomerCard.liveRectOf(customerId),
    onFitChanged: showFlyingCard,
    onEdit: onEdit,
    onDelete: onDelete,
    onManageRelationships: onManageRelationships,
    onCustomerUpdated: onCustomerUpdated,
  );
  await Future<void>.delayed(const Duration(milliseconds: 380));
  CustomerCard.flyingCustomerId.value = null;
}
