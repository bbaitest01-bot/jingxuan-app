import 'policy_scan_service.dart';

/// 掃描結果的合併與去重（從 policy_scan_service.dart 拆出，維持 500 行內）
class PolicyScanMerge {
  /// 去掉名稱與保費都一樣、緊接著重複出現的商品（切兩半時重疊處可能被列兩次）
  static void removeDuplicateItems(ScannedPolicy policy) {
    final List<ScannedPolicyItem> keptItems = [];
    for (final ScannedPolicyItem item in policy.items) {
      bool isDuplicate = false;
      for (final ScannedPolicyItem keptItem in keptItems) {
        final bool sameName = PolicyScanService.normalizeProductName(keptItem.productName) == PolicyScanService.normalizeProductName(item.productName);
        if (sameName && keptItem.premium == item.premium) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        keptItems.add(item);
      }
    }
    policy.items
      ..clear()
      ..addAll(keptItems);
  }

  /// 好幾張照片分開辨識後合成一份（2026-10-29 做法 A：封面、條款頁各自切兩半辨識）
  /// - 公司、保單號碼、生效日：取第一張有寫的
  /// - 總項數：取各張裡最大的（封面和條款頁可能都寫了總數，相加會變兩倍）
  /// - 商品：依照片順序合併；同名的只留一筆，保留資料比較多的那筆（有保費、有計畫）
  static ScannedPolicy mergePages(List<ScannedPolicy> pages) {
    final ScannedPolicy merged = ScannedPolicy(items: []);
    for (final ScannedPolicy page in pages) {
      merged.companyCode ??= page.companyCode;
      merged.companyName ??= page.companyName;
      merged.policyNumber ??= page.policyNumber;
      merged.effectiveDate ??= page.effectiveDate;
      final int? pageCount = page.expectedItemCount;
      final int? mergedCount = merged.expectedItemCount;
      if (pageCount != null && (mergedCount == null || pageCount > mergedCount)) {
        merged.expectedItemCount = pageCount;
      }
      if (page.sentWholePhoto) {
        merged.sentWholePhoto = true;
      }
      for (final ScannedPolicyItem item in page.items) {
        _addOrKeepRicher(merged.items, item);
      }
    }
    return merged;
  }

  /// 同名商品已經有了：保留保費、計畫比較完整的那筆；沒有就加在最後
  static void _addOrKeepRicher(List<ScannedPolicyItem> items, ScannedPolicyItem newItem) {
    final String newName = PolicyScanService.normalizeProductName(newItem.productName);
    for (int index = 0; index < items.length; index++) {
      if (PolicyScanService.normalizeProductName(items[index].productName) != newName) {
        continue;
      }
      if (_detailScore(newItem) > _detailScore(items[index])) {
        items[index] = newItem;
      }
      return;
    }
    items.add(newItem);
  }

  static int _detailScore(ScannedPolicyItem item) {
    int score = 0;
    if (item.premium != null) score++;
    if ((item.planOrAmount ?? '').isNotEmpty) score++;
    if (item.coverageRole != null) score++;
    return score;
  }
}
