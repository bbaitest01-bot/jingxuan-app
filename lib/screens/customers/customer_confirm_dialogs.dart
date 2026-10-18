import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 單一客戶「移到垃圾桶」確認視窗；按下刪除才呼叫 [onConfirm]
void showDeleteCustomerConfirm(
  BuildContext context, {
  required String name,
  required VoidCallback onConfirm,
}) {
  final AppColors colors = context.appColors;
  final Color dangerColor = Theme.of(context).colorScheme.error;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n('customer_delete_title'), style: AppTextStyles.serif(fontSize: 20, color: colors.ink)),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: colors.ink, fontSize: 14),
            children: [
              TextSpan(text: context.l10n('customer_delete_confirm_p1') + name + context.l10n('customer_delete_confirm_p2') + '\n\n'),
              TextSpan(
                text: '警告：這將連帶隱藏與該客戶相關的專案拜訪與行程紀錄！',
                style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n('cancel'), style: TextStyle(color: colors.ink2)),
          ),
          FilledButton(
            style: AppButtonStyles.danger(context),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: Text(context.l10n('delete')),
          ),
        ],
      );
    },
  );
}

/// 多選客戶「批量移到垃圾桶」確認視窗；按下確認才呼叫 [onConfirm]
void showBatchDeleteConfirm(
  BuildContext context, {
  required int count,
  required VoidCallback onConfirm,
}) {
  final AppColors colors = context.appColors;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 24),
          const SizedBox(width: 10),
          Text('確認批量移至垃圾桶', style: AppTextStyles.serif(fontSize: 20, color: colors.ink)),
        ],
      ),
      content: Text(
        '您確定要把選取的 $count 筆客戶資料移至垃圾桶嗎？\n移至垃圾桶後，您仍可隨時前往垃圾桶進行復原。',
        style: TextStyle(color: colors.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n('cancel'), style: TextStyle(color: colors.ink2)),
        ),
        FilledButton(
          style: AppButtonStyles.danger(context),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: Text('確認移至垃圾桶 ($count)'),
        ),
      ],
    ),
  );
}
