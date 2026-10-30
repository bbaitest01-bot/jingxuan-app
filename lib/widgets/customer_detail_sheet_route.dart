import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'customer_card_flight.dart';
import 'customer_detail_side_sheet.dart';

/// 打開客戶側邊欄（2026-10-30 從 customer_detail_side_sheet.dart 拆出，維持檔案行數）
///
/// 電腦版：右邊滑出；有傳 [originRect]、[flyingCard] 時，被點的卡片會飛到左邊中間。
/// 手機：從下方打開，不做飛的動畫。回傳的 Future 在側邊欄關掉後完成。
Future<void> showCustomerDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> customer,
  required Function(Map<String, dynamic>) onCustomerUpdated,
  Rect? originRect,
  Widget? flyingCard,
  Rect? Function()? currentOriginRect,
  EdgeInsets contentPadding = EdgeInsets.zero,
  ValueChanged<bool>? onFitChanged,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onManageRelationships,
}) {
  final bool isDesktop = MediaQuery.of(context).size.width >= 768;

  // 先關側邊欄、再做事（編輯、刪除會跳出另一個視窗）
  VoidCallback? closeThen(BuildContext sheetContext, VoidCallback? action) {
    if (action == null) return null;
    return () {
      Navigator.of(sheetContext).pop();
      action();
    };
  }

  if (isDesktop) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CustomerDetailSideSheet',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, animation, _) {
        final Widget sheet = SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: CustomerDetailSideSheet.desktopSheetWidth,
                height: double.infinity,
                // 滑進來的時候先只放底色，滑完再放內容（避免和飛的動畫搶時間而卡一下）
                child: ShowAfterAnimation(
                  animation: animation,
                  placeholder: const _SheetPlaceholder(),
                  child: CustomerDetailSideSheet(
                    customer: customer,
                    onCustomerUpdated: onCustomerUpdated,
                    onClose: () => Navigator.of(ctx).pop(),
                    onEdit: closeThen(ctx, onEdit),
                    onDelete: closeThen(ctx, onDelete),
                    onManageRelationships: onManageRelationships,
                  ),
                ),
              ),
            ),
          ),
        );
        final Rect? cardRect = originRect;
        final Widget? card = flyingCard;
        if (cardRect == null || card == null) return sheet;
        return Stack(
          children: [
            CustomerCardFlight(
              animation: animation,
              originRect: cardRect,
              sheetWidth: CustomerDetailSideSheet.desktopSheetWidth,
              card: card,
              currentOriginRect: currentOriginRect,
              contentPadding: contentPadding,
              onFitChanged: onFitChanged,
            ),
            Positioned.fill(child: sheet),
          ],
        );
      },
    );
  }

  // 手機：從下方打開，不做飛的動畫
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: CustomerDetailSideSheet(
          customer: customer,
          onCustomerUpdated: onCustomerUpdated,
          onClose: () => Navigator.of(ctx).pop(),
          onEdit: closeThen(ctx, onEdit),
          onDelete: closeThen(ctx, onDelete),
          onManageRelationships: onManageRelationships,
        ),
      );
    },
  );
}

/// 側邊欄滑進來時的底色（內容等滑完才放）
class _SheetPlaceholder extends StatelessWidget {
  const _SheetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
      ),
    );
  }
}
