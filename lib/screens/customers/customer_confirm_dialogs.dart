import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';

/// 單一客戶「移到垃圾桶」確認視窗；按下刪除才呼叫 [onConfirm]
void showDeleteCustomerConfirm(
  BuildContext context, {
  required String name,
  required VoidCallback onConfirm,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
  final Color textColor = isDark ? Colors.white : Colors.black87;
  final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: dialogBg,
        title: Text(context.l10n('customer_delete_title'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 14),
            children: [
              TextSpan(text: context.l10n('customer_delete_confirm_p1') + name + context.l10n('customer_delete_confirm_p2') + '\n\n'),
              TextSpan(
                text: '⚠️ 警告：這將連帶隱藏與該客戶相關的專案拜訪與行程紀錄！',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n('cancel'), style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : Colors.black87;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
          const SizedBox(width: 10),
          Text('確認批量移至垃圾桶', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(
        '您確定要把選取的 $count 筆客戶資料移至垃圾桶嗎？\n移至垃圾桶後，您仍可隨時前往垃圾桶進行復原。',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n('cancel'), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
