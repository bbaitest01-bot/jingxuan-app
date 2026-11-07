import 'package:flutter/material.dart';

import '../../services/insurance_product_service.dart';
import '../../theme/app_theme.dart';

/// 沒有給付項目、也沒有限額表的商品：說清楚為什麼（2026-11-07 沛沛：豁免保費附約只顯示一排「—」看起來像壞掉）
///
/// 這類商品共約 345 款，大多本身就不給付保險金：豁免保費、批註條款、年金、投資型、旅行平安險
String noBenefitExplanation(InsuranceProduct product) {
  final String name = product.productName;
  if (name.contains('豁免')) {
    return '這是豁免保費附約：不給付保險金。符合條款條件（例如要保人罹患重大疾病）時，之後的保費不用再繳，保障照樣有效。';
  }
  if (product.productKind == 'endorsement' || name.contains('批註')) {
    return '這是批註條款：用來修改主約的規則，本身不給付保險金。';
  }
  if (product.insuranceType == 'annuity' || name.contains('年金')) {
    return '這是年金保險：用來存錢、日後按期領回，不是出事才給錢，所以沒有情境試算。';
  }
  if (product.insuranceType == 'investment' || name.contains('投資') || name.contains('變額')) {
    return '這是投資型保險：金額跟著投資績效變動，沒有固定的給付金額可以試算。';
  }
  if (name.contains('旅行') || name.contains('旅平')) {
    return '這是旅行平安險：只在旅行期間有效，給付項目目前還沒整理。';
  }
  return '這款的給付項目還沒整理好，請點下方「官方條款 PDF」看原文。';
}

/// 欄位上方的灰色說明框
class NoBenefitNotice extends StatelessWidget {
  final InsuranceProduct product;

  const NoBenefitNotice({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Text(noBenefitExplanation(product), style: TextStyle(fontSize: 12, color: colors.ink2)),
    );
  }
}
