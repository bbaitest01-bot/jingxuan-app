import 'package:flutter/material.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'enroll_product_dialog.dart';
import 'insurance_product_card.dart';

/// 比較表每一欄最上方：商品代碼、移除按鈕、公司與商品名稱
class ComparisonColumnHeader extends StatelessWidget {
  final InsuranceProduct product;
  final VoidCallback onRemove;
  final bool canRemove;

  const ComparisonColumnHeader({super.key, required this.product, required this.onRemove, required this.canRemove});

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

/// 下方兩個按鈕：＋加到客戶、官方條款
/// （「全真醫療單據試算」2026-11-04 拿掉：一直停用、和保單健檢重疊，D26）
class ComparisonColumnActions extends StatelessWidget {
  final InsuranceProduct product;

  const ComparisonColumnActions({super.key, required this.product});

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
