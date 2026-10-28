import 'insurance_product_service.dart';

/// 掃描保單的辨識結果資料（從 policy_scan_service.dart 拆出，維持 500 行內；該檔會 export 本檔）

/// 辨識出來的一個商品（主約或附約）；確認畫面可以修改，所以欄位不是 final
class ScannedPolicyItem {
  String productName;
  String? coverageRole;
  String? planOrAmount;
  int? premium;
  // 保費幣別（TWD、USD…）；null 視為新臺幣
  String? premiumCurrency;
  // 對到的商品目錄資料；null 代表目錄找不到（照樣存，畫面標示）
  InsuranceProduct? matchedProduct;
  // 對不到時，目錄裡只差一兩個字的商品（AI 認錯字時用）；只顯示「可能是」，業務員按「套用」才換
  InsuranceProduct? suggestedProduct;
  // 補拍時新找到的項目（清單標「補拍新增」；2026-10-29 D19）
  bool addedByRetake = false;
  // 補拍讀到同一個商品、但保費或計畫不一樣：先不換，清單標黃讓業務員選
  ScannedPolicyItem? retakeAlternative;

  ScannedPolicyItem({
    required this.productName,
    this.coverageRole,
    this.planOrAmount,
    this.premium,
    this.premiumCurrency,
    this.matchedProduct,
    this.suggestedProduct,
  });

  bool get isInCatalog => matchedProduct != null;

  /// 按「套用」：換成建議的目錄商品
  void applySuggestion() {
    final InsuranceProduct? product = suggestedProduct;
    if (product == null) return;
    matchedProduct = product;
    productName = product.productName;
    suggestedProduct = null;
  }
}

/// 一份保單的辨識結果（只有商品相關欄位，沒有要保人、被保險人等個資）
class ScannedPolicy {
  String? companyCode;
  String? companyName;
  String? policyNumber;
  DateTime? effectiveDate;
  // AI 數出來保單上一共幾項；比讀到的項數多時，畫面提醒可能有漏
  int? expectedItemCount;
  // 照片沒有切成上下兩半、整張送去辨識（較容易漏項，畫面提醒；2026-10-28 D7 再次發生）
  bool sentWholePhoto = false;
  final List<ScannedPolicyItem> items;

  ScannedPolicy({
    this.companyCode,
    this.companyName,
    this.policyNumber,
    this.effectiveDate,
    this.expectedItemCount,
    required this.items,
  });

  /// 保單上應該有、但還沒列出來的項數（0 代表沒有漏）
  int get missingItemCount {
    final int? expected = expectedItemCount;
    if (expected == null || expected <= items.length) {
      return 0;
    }
    return expected - items.length;
  }
}
