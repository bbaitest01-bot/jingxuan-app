import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'custom_toast.dart';

/// 用外部瀏覽器打開官方條款 PDF；沒有連結時提示
Future<void> openOfficialClause(BuildContext context, InsuranceProduct product) async {
  if (!product.hasClauseUrl) {
    CustomToast.show(context, '這款商品官網沒有提供條款連結', ToastType.warning);
    return;
  }
  final Uri clauseUri = clauseOpenUri(product.clauseUrl!, Supabase.instance.client.rest.url);
  final bool opened = await launchUrl(clauseUri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    CustomToast.show(context, '無法開啟條款連結', ToastType.error);
  }
}

/// 要打開的條款網址：富邦的改經過我們的雲端函式 clause-pdf 轉送
/// （iPhone 直接點富邦條款會被轉到富邦金控首頁；D5 再次發生，2026-10-28），其他公司直接開
/// restUrl 是 Supabase 的 …/rest/v1，換成 …/functions/v1 就是雲端函式的位置
Uri clauseOpenUri(String clauseUrl, String restUrl) {
  final Uri originalUri = Uri.parse(clauseUrl);
  if (originalUri.host != 'www.fubon.com') {
    return originalUri;
  }
  final String functionsUrl = restUrl.replaceFirst(RegExp(r'/rest/v1/?$'), '/functions/v1');
  return Uri.parse('$functionsUrl/clause-pdf').replace(queryParameters: {'url': clauseUrl});
}

/// 商品資料的出處說明（數據戰情商品查詢、比較頁下方）
const String productDataSourceNotice =
    '資料來源：國泰、富邦、南山人壽官網「資訊公開」（商品清單、契約條款），每週自動更新；給付項目由官方條款整理，點格子可看原文，以官方條款為準。';

/// 比較頁「資料來源」列的文字：國泰人壽官網・資訊公開 ↗
String productSourceLabel(InsuranceProduct product) {
  if (product.sourceUrl.isEmpty) {
    return '${product.companyName}官網・資訊公開';
  }
  return '${product.companyName}官網・資訊公開 ↗';
}

/// 打開這款商品資料的官網來源頁（商品清單所在頁面）
Future<void> openProductSource(BuildContext context, InsuranceProduct product) async {
  if (product.sourceUrl.isEmpty) {
    CustomToast.show(context, '這款商品沒有記錄來源網址', ToastType.warning);
    return;
  }
  final bool opened = await launchUrl(Uri.parse(product.sourceUrl), mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    CustomToast.show(context, '無法開啟官網', ToastType.error);
  }
}

/// 核准日期顯示成 2022/09/29；沒有日期顯示「—」
String formatApprovalDate(DateTime? approvalDate) {
  if (approvalDate == null) {
    return '—';
  }
  return DateFormat('yyyy/MM/dd').format(approvalDate);
}

/// 數據戰情的商品卡片：點整張卡片勾選比較，右下角可開官方條款
class InsuranceProductCard extends StatelessWidget {
  final InsuranceProduct product;
  final bool isSelected;
  final VoidCallback onToggleSelected;

  const InsuranceProductCard({
    super.key,
    required this.product,
    required this.isSelected,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color borderColor = colors.line;
    double borderWidth = 1;
    if (isSelected) {
      borderColor = colors.acc;
      borderWidth = 2;
    }

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onToggleSelected,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardTopRow(product: product, isSelected: isSelected),
                  const SizedBox(height: 8),
                  Text(
                    product.companyName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.acc),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.productName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              _CardBottomRow(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片上方：代碼、險種、主約／附約，右邊是勾選圈
class _CardTopRow extends StatelessWidget {
  final InsuranceProduct product;
  final bool isSelected;

  const _CardTopRow({required this.product, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        ProductInfoChip(text: product.displayCode, isMono: true),
        const SizedBox(width: 6),
        ProductInfoChip(text: product.insuranceTypeLabel, highlighted: true),
        const SizedBox(width: 6),
        ProductInfoChip(text: product.productKindLabel),
        const Spacer(),
        _SelectionCircle(isSelected: isSelected, colors: colors),
      ],
    );
  }
}

/// 卡片下方：首次核准日期、查看條款
class _CardBottomRow extends StatelessWidget {
  final InsuranceProduct product;

  const _CardBottomRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 12, color: colors.line),
        Row(
          children: [
            Text('首次核准 ', style: TextStyle(fontSize: 10.5, color: colors.ink3)),
            Text(
              formatApprovalDate(product.approvalDate),
              style: AppTextStyles.mono(fontSize: 10.5, color: colors.ink2),
            ),
            const Spacer(),
            if (product.hasClauseUrl)
              TextButton.icon(
                onPressed: () => openOfficialClause(context, product),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                label: const Text('查看條款', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: colors.acc,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
              )
            else
              Text('無條款連結', style: TextStyle(fontSize: 10.5, color: colors.ink3)),
          ],
        ),
      ],
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  final bool isSelected;
  final AppColors colors;

  const _SelectionCircle({required this.isSelected, required this.colors});

  @override
  Widget build(BuildContext context) {
    Color fillColor = Colors.transparent;
    Color outlineColor = colors.line;
    Color iconColor = colors.ink3;
    IconData icon = Icons.add;
    if (isSelected) {
      fillColor = colors.acc;
      outlineColor = colors.acc;
      iconColor = colors.onAcc;
      icon = Icons.check;
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: outlineColor, width: 1.5),
      ),
      child: Icon(icon, size: 12, color: iconColor),
    );
  }
}

/// 小標籤：代碼用等寬字；險種用主題色突顯
class ProductInfoChip extends StatelessWidget {
  final String text;
  final bool isMono;
  final bool highlighted;

  const ProductInfoChip({super.key, required this.text, this.isMono = false, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color backgroundColor = colors.surface2;
    Color textColor = colors.ink2;
    if (highlighted) {
      backgroundColor = colors.accSoft;
      textColor = colors.acc;
    }

    TextStyle textStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor);
    if (isMono) {
      textStyle = AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w600, color: textColor);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: textStyle),
    );
  }
}
