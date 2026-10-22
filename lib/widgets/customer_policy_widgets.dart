import 'package:flutter/material.dart';
import '../services/customer_policy_service.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'insurance_product_card.dart';

/// 限額文字：沒有資料時顯示「建置中」，不顯示假數字
String limitTextOrNotReady(String limitText) {
  if (limitText.trim().isEmpty) {
    return '建置中';
  }
  return limitText;
}

/// 客戶「保單健檢與缺口」的理賠總額卡片
///
/// 只加總有理賠限額資料的保單；真實商品還沒有第二層比價資料，會列在「未納入計算」。
class BenefitSummaryCard extends StatelessWidget {
  final CustomerBenefitSummary? summary;

  const BenefitSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final int countedCount = summary?.countedPolicyCount ?? 0;
    final int notCountedCount = summary?.policiesWithoutLimitCount ?? 0;

    final List<Widget> rows = [];
    if (countedCount == 0) {
      rows.add(Text(
        '理賠限額資料建置中，暫時無法計算保障總額與缺口。',
        style: TextStyle(fontSize: 12, color: colors.ink3),
      ));
    } else {
      rows.add(_SummaryRow(label: '病房給付總額', value: '${summary!.totalRoomDaily} 元/日', icon: Icons.hotel_rounded));
      rows.add(_SummaryRow(label: '手術給付上限', value: '${summary!.totalSurgeryMax} 元', icon: Icons.medical_services_rounded));
      rows.add(_SummaryRow(label: '自費雜費總額', value: '${summary!.totalMiscMax} 元', icon: Icons.receipt_rounded));
      rows.add(_SummaryRow(
        label: '癌症重疾一次金',
        value: '${summary!.totalCancerCriticalMax ~/ 10000} 萬元',
        icon: Icons.coronavirus_rounded,
      ));
    }
    if (notCountedCount > 0) {
      rows.add(const SizedBox(height: 6));
      rows.add(Text(
        '$notCountedCount 張保單尚無理賠限額資料，未納入計算',
        style: TextStyle(fontSize: 11, color: colors.ink3),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.acc.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: colors.acc, size: 18),
              const SizedBox(width: 8),
              Text('理賠總額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.ink3),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: colors.ink2))),
          Text(value, style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink)),
        ],
      ),
    );
  }
}

/// 「加入保單」搜尋結果的一列：公司、險種、商品名稱、＋加入
class CatalogProductResultTile extends StatelessWidget {
  final InsuranceProduct product;
  final VoidCallback onEnroll;

  const CatalogProductResultTile({super.key, required this.product, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ProductInfoChip(text: product.companyName, highlighted: true),
                    ProductInfoChip(text: product.insuranceTypeLabel),
                    ProductInfoChip(text: product.productKindLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.productName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            onPressed: onEnroll,
            child: const Text('+ 加入', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
