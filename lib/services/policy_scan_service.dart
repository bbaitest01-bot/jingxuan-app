import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_policy_service.dart';
import 'insurance_product_service.dart';

/// 一張要送去辨識的保單影像（照片、截圖，或 PDF 轉出來的頁面）
class PolicyScanImage {
  final Uint8List bytes;
  final String mimeType;

  const PolicyScanImage({required this.bytes, required this.mimeType});
}

/// 辨識出來的一個商品（主約或附約）；確認畫面可以修改，所以欄位不是 final
class ScannedPolicyItem {
  String productName;
  String? coverageRole;
  String? planOrAmount;
  int? premium;
  // 對到的商品目錄資料；null 代表目錄找不到（照樣存，畫面標示）
  InsuranceProduct? matchedProduct;

  ScannedPolicyItem({
    required this.productName,
    this.coverageRole,
    this.planOrAmount,
    this.premium,
    this.matchedProduct,
  });

  bool get isInCatalog => matchedProduct != null;
}

/// 一份保單的辨識結果（只有商品相關欄位，沒有要保人、被保險人等個資）
class ScannedPolicy {
  String? companyCode;
  String? companyName;
  String? policyNumber;
  DateTime? effectiveDate;
  final List<ScannedPolicyItem> items;

  ScannedPolicy({
    this.companyCode,
    this.companyName,
    this.policyNumber,
    this.effectiveDate,
    required this.items,
  });
}

/// 辨識失敗時給畫面看的訊息
class PolicyScanException implements Exception {
  final String message;

  const PolicyScanException(this.message);

  @override
  String toString() => message;
}

/// 掃描保單（第 5 階段 E；設計見全景地圖 4-J）
///
/// 1. recognizePolicy()：把影像送到雲端函式 scan-policy，拿回商品欄位
/// 2. matchCatalog()：每個商品去對商品目錄（同公司、名稱相同）
/// 3. saveScannedPolicy()：業務員確認後，一個商品存一筆到 customer_policies
class PolicyScanService {
  static final PolicyScanService _instance = PolicyScanService._internal();
  factory PolicyScanService() => _instance;
  PolicyScanService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 目前目錄有的三家公司：保單上的公司名稱關鍵字 → 目錄的公司代號
  static const Map<String, String> companyKeywords = {
    '國泰': 'cathay',
    '富邦': 'fubon',
    '南山': 'nanshan',
  };

  static const Map<String, String> companyShortNames = {
    'cathay': '國泰人壽',
    'fubon': '富邦人壽',
    'nanshan': '南山人壽',
  };

  // ---------------------------------------------------------------------------
  // 第一次使用的說明（每位業務員在這台裝置上同意一次）
  // ---------------------------------------------------------------------------
  String _noticeKey() {
    final String userId = _supabase.auth.currentUser?.id ?? 'guest';
    return 'scan_policy_notice_agreed_$userId';
  }

  Future<bool> hasAgreedToNotice() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_noticeKey()) ?? false;
  }

  Future<void> markNoticeAgreed() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_noticeKey(), true);
  }

  // ---------------------------------------------------------------------------
  // 1. 送去辨識
  // ---------------------------------------------------------------------------
  Future<ScannedPolicy> recognizePolicy(List<PolicyScanImage> images) async {
    final List<Map<String, String>> imagePayload = [];
    for (final PolicyScanImage image in images) {
      imagePayload.add({'base64': base64Encode(image.bytes), 'mimeType': image.mimeType});
    }

    // 雲端函式剛啟動、連線中斷時自動再試一次；AI 本身的重試在雲端函式裡做
    Map<String, dynamic>? responseData;
    for (int attempt = 1; attempt <= 2 && responseData == null; attempt++) {
      try {
        final FunctionResponse response = await _supabase.functions.invoke(
          'scan-policy',
          body: {'images': imagePayload},
        );
        responseData = Map<String, dynamic>.from(response.data as Map);
      } on FunctionException catch (error) {
        final bool isLastAttempt = attempt == 2;
        if (!isServerStartupProblem(error.status) || isLastAttempt) {
          throw PolicyScanException(_errorMessageFrom(error.details));
        }
      } catch (error) {
        if (kDebugMode) debugPrint('掃描保單失敗（第 $attempt 次）: $error');
        if (attempt == 2) {
          throw const PolicyScanException('連線失敗，請檢查網路後再試');
        }
      }
    }

    final ScannedPolicy policy = parseScanResponse(responseData ?? const {});
    if (policy.items.isEmpty) {
      throw const PolicyScanException('沒有讀到商品，請確認拍的是「保單首頁」（列出主約、附約那一頁）');
    }
    return policy;
  }

  /// 伺服器還沒準備好（啟動中、逾時）才值得重試；照片格式錯、AI 失敗（502）不重試
  static bool isServerStartupProblem(int status) {
    return status == 500 || status == 503 || status == 504 || status == 546;
  }

  String _errorMessageFrom(dynamic details) {
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'AI 辨識暫時無法使用，請稍後再試或改用手動輸入';
  }

  /// 把雲端函式回傳的 JSON 轉成 ScannedPolicy（另外拉出來方便測試）
  static ScannedPolicy parseScanResponse(Map<String, dynamic> data) {
    final List<ScannedPolicyItem> items = [];
    final List<dynamic> rawItems = data['items'] is List ? data['items'] as List : const [];
    for (final dynamic rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final String productName = rawItem['product_name']?.toString().trim() ?? '';
      if (productName.isEmpty) continue;
      items.add(ScannedPolicyItem(
        productName: productName,
        coverageRole: rawItem['coverage_role'] as String?,
        planOrAmount: rawItem['plan_or_amount'] as String?,
        premium: (rawItem['premium'] as num?)?.toInt(),
      ));
    }

    final String? companyName = data['company_name'] as String?;
    String? companyCode = companyCodeFromText(companyName ?? '');
    // 保單上沒讀到公司名稱時，從商品名稱（例：國泰人壽…）推回來
    if (companyCode == null && items.isNotEmpty) {
      companyCode = companyCodeFromText(items.first.productName);
    }

    return ScannedPolicy(
      companyCode: companyCode,
      companyName: companyName,
      policyNumber: data['policy_number'] as String?,
      effectiveDate: DateTime.tryParse(data['effective_date']?.toString() ?? ''),
      items: items,
    );
  }

  /// 從文字找出是哪一家公司；目錄沒有的公司回傳 null
  static String? companyCodeFromText(String text) {
    for (final MapEntry<String, String> entry in companyKeywords.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. 對商品目錄
  // ---------------------------------------------------------------------------

  /// 讀出該公司的全部商品，替每個辨識出的商品找出目錄中名稱相同的那一筆
  Future<void> matchCatalog(ScannedPolicy policy) async {
    final String? companyCode = policy.companyCode;
    if (companyCode == null) {
      return;
    }
    final List<InsuranceProduct> companyProducts = await InsuranceProductService().fetchCompanyProducts(companyCode);
    for (final ScannedPolicyItem item in policy.items) {
      item.matchedProduct = findCatalogMatch(item.productName, companyProducts);
    }
  }

  /// 名稱比對：去掉公司名稱、空白、括號差異後要完全相同才算對到。
  /// 不用「包含」比對，避免「新終身防癌」被對成舊的「終身防癌」這種錯誤；
  /// 對不到時由業務員在確認畫面自己搜尋選擇。
  static InsuranceProduct? findCatalogMatch(String scannedName, List<InsuranceProduct> candidates) {
    final String target = normalizeProductName(scannedName);
    if (target.isEmpty) {
      return null;
    }
    for (final InsuranceProduct product in candidates) {
      if (normalizeProductName(product.productName) == target) {
        return product;
      }
    }
    return null;
  }

  static String normalizeProductName(String name) {
    String result = name;
    result = result.replaceAll(RegExp(r'\s+'), '');
    result = result.replaceAll('（', '(').replaceAll('）', ')');
    result = result.replaceAll(RegExp(r'(國泰|富邦|南山)人壽(保險股份有限公司)?'), '');
    return result;
  }

  // ---------------------------------------------------------------------------
  // 3. 存入客戶保單（整份一次寫入：要嘛全部成功，要嘛全部失敗）
  // ---------------------------------------------------------------------------
  Future<void> saveScannedPolicy({
    required String customerId,
    required ScannedPolicy policy,
    required String status,
  }) async {
    final List<Map<String, dynamic>> rows = buildPolicyRows(
      customerId: customerId,
      policy: policy,
      status: status,
      policyGroupId: generateUuid(),
    );
    if (rows.isEmpty) {
      throw const PolicyScanException('沒有可以存入的商品');
    }
    try {
      await _supabase.from('customer_policies').insert(rows);
    } catch (error) {
      if (kDebugMode) debugPrint('存入掃描保單失敗: $error');
      throw const PolicyScanException('存入失敗，請檢查網路後再試');
    }
    CustomerPolicyService().clearCachedPolicies(customerId);
  }

  /// 組出要寫入資料庫的每一筆（另外拉出來方便測試）
  static List<Map<String, dynamic>> buildPolicyRows({
    required String customerId,
    required ScannedPolicy policy,
    required String status,
    required String policyGroupId,
  }) {
    final String fallbackCompanyName = companyShortNames[policy.companyCode] ?? policy.companyName ?? '未知公司';
    String? effectiveDateText;
    final DateTime? effectiveDate = policy.effectiveDate;
    if (effectiveDate != null) {
      effectiveDateText = effectiveDate.toIso8601String().substring(0, 10);
    }

    final List<Map<String, dynamic>> rows = [];
    for (final ScannedPolicyItem item in policy.items) {
      final String productName = item.productName.trim();
      if (productName.isEmpty) continue;
      final InsuranceProduct? product = item.matchedProduct;

      rows.add({
        'customer_id': customerId,
        'policy_clause_id': product?.id,
        'product_name': product?.productName ?? productName,
        'company_name': product?.companyName ?? fallbackCompanyName,
        'category': product?.insuranceTypeLabel ?? '未分類',
        // 明確寫入空值，不讓資料表的預設值（2,000 元/日 等假數字）補上
        'room_limit': null,
        'surgery_limit': null,
        'misc_limit': null,
        'benefits_json': <String, dynamic>{},
        'raw_pdf_url': product?.clauseUrl,
        'status': status,
        'policy_group_id': policyGroupId,
        'policy_number': policy.policyNumber,
        'coverage_role': item.coverageRole,
        'plan_or_amount': item.planOrAmount,
        'effective_date': effectiveDateText,
        'premium': item.premium,
        'source': 'scan',
      });
    }
    return rows;
  }

  /// 產生一組隨機 UUID（第 4 版格式），當作同一份保單的 policy_group_id
  static String generateUuid() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (int index) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < bytes.length; index++) {
      if (index == 4 || index == 6 || index == 8 || index == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[index].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
