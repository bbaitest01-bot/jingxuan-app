import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/benefit_item_service.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';
import 'insurance_product_card.dart';

/// 保單比較頁「給付項目（條款）」區塊的文字與原文視窗（第 5 階段 D 第 2 層）

/// 這款商品沒有這個項目
const String benefitItemNotIncludedText = '✕ 沒有';

/// 有這個項目，但條款算法太複雜、沒有整理成短句
const String benefitItemSeeClauseText = '依條款（點看原文）';

/// 這款商品還沒有給付項目資料（不是定額型，或條款讀不到）
const String benefitItemNoDataText = '—';

/// 表格下方的說明
const String benefitItemNotice = '給付項目由條款自動整理：「保額」「日額」是客戶投保時買的金額，括號內用每 1 萬元保額、每 1,000 元日額換算可領多少；點格子可看條款原文，以官方條款為準。';

/// 某款商品、某一列要顯示的文字
String benefitItemCellText(List<InsuranceBenefitItem> productItems, String itemKey) {
  if (productItems.isEmpty) {
    return benefitItemNoDataText;
  }
  final InsuranceBenefitItem? item = BenefitItemService.findItem(productItems, itemKey);
  if (item == null) {
    return benefitItemNotIncludedText;
  }
  final String? formula = item.formula;
  if (formula == null) {
    return benefitItemSeeClauseText;
  }
  final String? example = benefitItemExampleText(formula);
  if (example == null) {
    return formula;
  }
  return '$formula\n（$example）';
}

/// 把算法換成看得到的金額：保額用每 1 萬元、日額用每 1,000 元來算
/// 「保額 × 10%」→「每萬元保額可領 1,000 元」；「日額 × 3 × 天數」→「日額 1,000 元，每天可領 3,000 元」
/// 「每單位 50,000 元」本身就是金額、「附表比例」算不出固定數字，回傳 null
String? benefitItemExampleText(String formula) {
  // 「保額 × 1%～115%（依投保第幾年）」是範圍，不換算單一金額
  if (formula.contains('～')) {
    return null;
  }
  // 分情況的（第2年起：保額 × 5（第1年內：…））取第一個算法，就是主要的那一種
  final RegExpMatch? match = RegExp(r'(保額|日額) × ([\d.]+)(%?)([^（；／]*)').firstMatch(formula);
  if (match == null) {
    return null;
  }
  final String base = match.group(1)!;
  final double multiplier = double.parse(match.group(2)!);
  final bool isPercent = match.group(3) == '%';
  final bool isPerDay = match.group(4)!.contains('天數');

  // 換算的基準：保額每 1 萬元、日額每 1,000 元
  int baseAmount = 10000;
  String baseText = '每萬元保額';
  if (base == '日額') {
    baseAmount = 1000;
    baseText = '日額 1,000 元，';
  }

  double amount = baseAmount * multiplier;
  if (isPercent) {
    amount = amount / 100;
  }
  final String amountText = NumberFormat('#,###').format(amount.round());
  if (isPerDay) {
    return '$baseText每天可領 $amountText 元';
  }
  return '$baseText可領 $amountText 元';
}

/// 點格子：顯示條款原文那一句，可以再打開官方條款 PDF
Future<void> showBenefitItemSource(BuildContext context, InsuranceProduct product, InsuranceBenefitItem item) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppColors colors = dialogContext.appColors;
      String formulaText = '條款寫法較複雜，請看下方原文';
      final String? formula = item.formula;
      if (formula != null) {
        formulaText = '怎麼算：$formula';
      }
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(item.itemName, style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.productName, style: TextStyle(fontSize: 12, color: colors.ink3)),
              const SizedBox(height: 10),
              Text(formulaText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text('條款原文：${item.sourceExcerpt}', style: TextStyle(fontSize: 12, height: 1.5, color: colors.ink2)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => openOfficialClause(dialogContext, product),
            child: const Text('官方條款 PDF'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('關閉')),
        ],
      );
    },
  );
}
