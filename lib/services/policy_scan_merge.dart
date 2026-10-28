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

/// 補拍的比對結果（2026-10-29 D19：不要整張重拍，只補拍漏掉的部分再比對）
class RetakeResult {
  // 補拍的保單號碼或保險公司和第一次不同（可能拿錯保單）；例：「A123 → B456」
  final String? mismatchText;
  // 第一次沒有、補拍才讀到的項目
  final List<ScannedPolicyItem> newItems;
  // 同一個商品，保費或計畫不一樣（第一次的那筆 → 補拍讀到的）
  final Map<ScannedPolicyItem, ScannedPolicyItem> conflicts;
  // 和第一次完全一樣、略過的項數
  final int duplicateCount;

  const RetakeResult({
    required this.mismatchText,
    required this.newItems,
    required this.conflicts,
    required this.duplicateCount,
  });
}

/// 補拍的比對與套用
class PolicyRetake {
  /// 比對第一次與補拍的結果；不改任何資料
  static RetakeResult compare(ScannedPolicy current, ScannedPolicy retake) {
    final List<ScannedPolicyItem> newItems = [];
    final Map<ScannedPolicyItem, ScannedPolicyItem> conflicts = {};
    int duplicateCount = 0;
    for (final ScannedPolicyItem retakeItem in retake.items) {
      final ScannedPolicyItem? sameItem = _findSameProduct(current.items, retakeItem);
      if (sameItem == null) {
        newItems.add(retakeItem);
      } else if (_valuesDiffer(sameItem, retakeItem)) {
        conflicts[sameItem] = retakeItem;
      } else {
        duplicateCount++;
      }
    }
    return RetakeResult(
      mismatchText: _mismatchText(current, retake),
      newItems: newItems,
      conflicts: conflicts,
      duplicateCount: duplicateCount,
    );
  }

  /// 套用：新項目加在最後並標「補拍新增」；金額不同的標在原本那筆上讓業務員選；第一次沒讀到的保單資料補上
  static void apply(ScannedPolicy current, ScannedPolicy retake, RetakeResult result) {
    for (final ScannedPolicyItem item in result.newItems) {
      item.addedByRetake = true;
      current.items.add(item);
    }
    result.conflicts.forEach((ScannedPolicyItem original, ScannedPolicyItem retakeItem) {
      original.retakeAlternative = retakeItem;
    });
    current.policyNumber ??= retake.policyNumber;
    current.effectiveDate ??= retake.effectiveDate;
    current.companyCode ??= retake.companyCode;
    current.companyName ??= retake.companyName;
  }

  /// 業務員選「改用補拍的」：保費、計畫換成補拍讀到的
  static void useRetakeValue(ScannedPolicyItem item) {
    final ScannedPolicyItem? alternative = item.retakeAlternative;
    if (alternative == null) return;
    item.premium = alternative.premium ?? item.premium;
    item.premiumCurrency = alternative.premiumCurrency ?? item.premiumCurrency;
    if ((alternative.planOrAmount ?? '').isNotEmpty) {
      item.planOrAmount = alternative.planOrAmount;
    }
    item.retakeAlternative = null;
  }

  static ScannedPolicyItem? _findSameProduct(List<ScannedPolicyItem> items, ScannedPolicyItem target) {
    final String targetName = PolicyScanService.normalizeProductName(target.productName);
    for (final ScannedPolicyItem item in items) {
      if (PolicyScanService.normalizeProductName(item.productName) == targetName) {
        return item;
      }
    }
    return null;
  }

  /// 兩邊都有值、而且不一樣才算不同（其中一邊沒讀到不算）
  static bool _valuesDiffer(ScannedPolicyItem first, ScannedPolicyItem second) {
    final bool premiumDiffers = first.premium != null && second.premium != null && first.premium != second.premium;
    final String firstPlan = (first.planOrAmount ?? '').replaceAll(' ', '');
    final String secondPlan = (second.planOrAmount ?? '').replaceAll(' ', '');
    final bool planDiffers = firstPlan.isNotEmpty && secondPlan.isNotEmpty && firstPlan != secondPlan;
    return premiumDiffers || planDiffers;
  }

  /// 保單號碼或保險公司不同時回傳說明；看不出來（有一邊沒讀到）不算不同
  static String? _mismatchText(ScannedPolicy current, ScannedPolicy retake) {
    final String currentNumber = (current.policyNumber ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final String retakeNumber = (retake.policyNumber ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (currentNumber.isNotEmpty && retakeNumber.isNotEmpty && currentNumber != retakeNumber) {
      return '保單號碼 ${current.policyNumber} → ${retake.policyNumber}';
    }
    final String? currentCompany = current.companyCode;
    final String? retakeCompany = retake.companyCode;
    if (currentCompany != null && retakeCompany != null && currentCompany != retakeCompany) {
      final String currentName = PolicyScanService.companyShortNames[currentCompany] ?? currentCompany;
      final String retakeName = PolicyScanService.companyShortNames[retakeCompany] ?? retakeCompany;
      return '保險公司 $currentName → $retakeName';
    }
    return null;
  }
}
