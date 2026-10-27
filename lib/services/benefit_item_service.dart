import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 定額型商品的一個給付項目（資料表 insurance_product_benefit_items；第 5 階段 D 第 2 層）
///
/// 例：癌症險的「初次罹患癌症（重度）」、手術險的「門診手術醫療」。
/// formula 是「怎麼算」（保額 × 10%）；條款寫法太複雜時是 null，畫面請業務員看原文。
class InsuranceBenefitItem {
  final String productId;
  final int itemOrder;
  final String itemKey;
  final String itemName;
  final String? formula;
  final String sourceExcerpt;

  const InsuranceBenefitItem({
    required this.productId,
    required this.itemOrder,
    required this.itemKey,
    required this.itemName,
    this.formula,
    required this.sourceExcerpt,
  });

  factory InsuranceBenefitItem.fromJson(Map<String, dynamic> json) {
    return InsuranceBenefitItem(
      productId: json['product_id']?.toString() ?? '',
      itemOrder: (json['item_order'] as num?)?.toInt() ?? 0,
      itemKey: json['item_key']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      formula: json['formula'] as String?,
      sourceExcerpt: json['source_excerpt']?.toString() ?? '',
    );
  }
}

/// 讀給付項目，並整理成比較表的列
class BenefitItemService {
  static final BenefitItemService _instance = BenefitItemService._internal();
  factory BenefitItemService() => _instance;
  BenefitItemService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 一次查好幾款商品的給付項目；{商品 id: 依條款順序排好的項目}
  Future<Map<String, List<InsuranceBenefitItem>>> fetchItemsForProducts(List<String> productIds) async {
    final Map<String, List<InsuranceBenefitItem>> itemsByProduct = {};
    if (productIds.isEmpty) {
      return itemsByProduct;
    }
    try {
      final List<dynamic> rows = await _supabase
          .from('insurance_product_benefit_items')
          .select()
          .inFilter('product_id', productIds)
          .order('item_order');
      for (final dynamic row in rows) {
        final InsuranceBenefitItem item = InsuranceBenefitItem.fromJson(row as Map<String, dynamic>);
        itemsByProduct.putIfAbsent(item.productId, () => []).add(item);
      }
    } catch (error) {
      // 讀不到時當作沒有給付項目，比較頁照樣可以看其他資料
      if (kDebugMode) debugPrint('讀取給付項目失敗: $error');
    }
    return itemsByProduct;
  }

  /// 比較表的列：把每款商品的項目名稱合在一起，依第一款、第二款…的條款順序排，重複的只留一次
  static List<String> orderedItemKeys(List<List<InsuranceBenefitItem>> itemListsInProductOrder) {
    final List<String> keys = [];
    for (final List<InsuranceBenefitItem> items in itemListsInProductOrder) {
      for (final InsuranceBenefitItem item in items) {
        if (!keys.contains(item.itemKey)) {
          keys.add(item.itemKey);
        }
      }
    }
    return keys;
  }

  /// 在某款商品的項目中找某一列；沒有回傳 null
  static InsuranceBenefitItem? findItem(List<InsuranceBenefitItem> items, String itemKey) {
    for (final InsuranceBenefitItem item in items) {
      if (item.itemKey == itemKey) {
        return item;
      }
    }
    return null;
  }
}
