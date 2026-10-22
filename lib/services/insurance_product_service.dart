import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 真實保險商品（資料表 insurance_products，5-2a 從國泰、富邦、南山官網抓取）
///
/// 只有第一層「商品目錄」：名稱、代碼、文號、條款連結。
/// 病房、手術、雜費等理賠限額是第二層比價資料，目前還沒有（見全景地圖 4-H）。
class InsuranceProduct {
  final String id;
  final String companyCode;
  final String companyName;
  final String? productCode;
  final String productName;
  final String productKind;
  final String? insuranceType;
  final String sourceCategory;
  final DateTime? approvalDate;
  final String? approvalNumber;
  final String? approvalHistory;
  final String? clauseUrl;
  final String sourceUrl;

  const InsuranceProduct({
    required this.id,
    required this.companyCode,
    required this.companyName,
    required this.productCode,
    required this.productName,
    required this.productKind,
    required this.insuranceType,
    required this.sourceCategory,
    required this.approvalDate,
    required this.approvalNumber,
    required this.approvalHistory,
    required this.clauseUrl,
    required this.sourceUrl,
  });

  factory InsuranceProduct.fromJson(Map<String, dynamic> json) {
    final String? approvalDateText = json['approval_date'] as String?;
    DateTime? approvalDate;
    if (approvalDateText != null) {
      approvalDate = DateTime.tryParse(approvalDateText);
    }

    return InsuranceProduct(
      id: json['id']?.toString() ?? '',
      companyCode: json['company_code']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      productCode: json['product_code'] as String?,
      productName: json['product_name']?.toString() ?? '',
      productKind: json['product_kind']?.toString() ?? 'main',
      insuranceType: json['insurance_type'] as String?,
      sourceCategory: json['source_category']?.toString() ?? '',
      approvalDate: approvalDate,
      approvalNumber: json['approval_number'] as String?,
      approvalHistory: json['approval_history'] as String?,
      clauseUrl: json['clause_url'] as String?,
      sourceUrl: json['source_url']?.toString() ?? '',
    );
  }

  /// 險種中文名稱（例：medical → 醫療）
  String get insuranceTypeLabel {
    return InsuranceProductService.insuranceTypeLabels[insuranceType] ?? '其他';
  }

  /// 主約／附約／批註條款
  String get productKindLabel {
    return InsuranceProductService.productKindLabels[productKind] ?? '主約';
  }

  /// 卡片上顯示的代碼：官網找不到代碼時顯示「無代碼」
  String get displayCode {
    final String code = productCode ?? '';
    if (code.isEmpty) {
      return '無代碼';
    }
    return code;
  }

  bool get hasClauseUrl {
    final String url = clauseUrl ?? '';
    return url.startsWith('https://');
  }
}

/// 一頁搜尋結果
class InsuranceProductSearchResult {
  final List<InsuranceProduct> products;
  final int totalCount;
  final int page;
  final int pageSize;

  const InsuranceProductSearchResult({
    required this.products,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages {
    if (totalCount <= 0) {
      return 1;
    }
    return (totalCount / pageSize).ceil();
  }
}

/// 商品目錄概況：總筆數與最後一次成功抓取的時間
class ProductCatalogSummary {
  final int totalCount;
  final DateTime? lastUpdatedAt;

  const ProductCatalogSummary({required this.totalCount, required this.lastUpdatedAt});
}

/// 讀取真實保險商品目錄（登入者唯讀，資料由排程寫入，App 不會修改）
class InsuranceProductService {
  static final InsuranceProductService _instance = InsuranceProductService._internal();
  factory InsuranceProductService() => _instance;
  InsuranceProductService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 資料庫險種代號 → 畫面顯示的中文；順序就是篩選按鈕的順序
  static const Map<String, String> insuranceTypeLabels = {
    'medical': '醫療',
    'cancer': '癌症',
    'critical_illness': '重大疾病',
    'long_term_care': '長期照顧',
    'accident': '意外傷害',
    'life': '壽險',
    'annuity': '年金',
    'investment': '投資型',
    'other': '其他',
  };

  static const Map<String, String> productKindLabels = {
    'main': '主約',
    'rider': '附約',
    'endorsement': '批註條款',
  };

  /// 每頁固定要讀的欄位（不讀 created_at 等用不到的欄位）
  static const String _selectedColumns =
      'id, company_code, company_name, product_code, product_name, product_kind, insurance_type, '
      'source_category, approval_date, approval_number, approval_history, clause_url, source_url';

  /// 把搜尋文字切成關鍵字；拿掉逗號、括號等符號，避免組出錯誤的查詢條件
  static List<String> splitKeywords(String query) {
    final String cleaned = query.replaceAll(RegExp(r'[,()%*\\]'), ' ');
    final List<String> keywords = [];
    for (final String part in cleaned.trim().split(RegExp(r'\s+'))) {
      if (part.isNotEmpty) {
        keywords.add(part);
      }
    }
    return keywords;
  }

  /// 依關鍵字、險種搜尋商品（每個關鍵字都要出現在名稱、公司或代碼其中之一）
  Future<InsuranceProductSearchResult> searchProducts({
    String query = '',
    String? insuranceType,
    bool includeEndorsements = false,
    int page = 1,
    int pageSize = 12,
  }) async {
    try {
      var request = _supabase.from('insurance_products').select(_selectedColumns);

      for (final String keyword in splitKeywords(query)) {
        request = request.or(
          'product_name.ilike.%$keyword%,company_name.ilike.%$keyword%,product_code.ilike.%$keyword%',
        );
      }
      if (insuranceType != null) {
        request = request.eq('insurance_type', insuranceType);
      }
      // 批註條款不能單獨購買，預設不顯示
      if (!includeEndorsements) {
        request = request.neq('product_kind', 'endorsement');
      }

      final int from = (page - 1) * pageSize;
      final int to = from + pageSize - 1;
      final response = await request
          .order('company_name')
          .order('product_name')
          .range(from, to)
          .count(CountOption.exact);

      final List<InsuranceProduct> products = [];
      for (final dynamic row in response.data as List) {
        products.add(InsuranceProduct.fromJson(row as Map<String, dynamic>));
      }
      return InsuranceProductSearchResult(
        products: products,
        totalCount: response.count,
        page: page,
        pageSize: pageSize,
      );
    } catch (error) {
      if (kDebugMode) print('搜尋保險商品失敗: $error');
      return InsuranceProductSearchResult(products: const [], totalCount: 0, page: page, pageSize: pageSize);
    }
  }

  /// 商品總數與最後一次成功抓取的時間（畫面顯示「資料更新：…」）
  Future<ProductCatalogSummary> fetchCatalogSummary() async {
    try {
      final countResponse = await _supabase.from('insurance_products').select('id').count(CountOption.exact);
      final Map<String, dynamic>? latestRun = await _supabase
          .from('product_crawl_runs')
          .select('finished_at')
          .eq('status', 'success')
          .order('finished_at', ascending: false)
          .limit(1)
          .maybeSingle();

      DateTime? lastUpdatedAt;
      final String? finishedAtText = latestRun?['finished_at'] as String?;
      if (finishedAtText != null) {
        lastUpdatedAt = DateTime.tryParse(finishedAtText)?.toLocal();
      }
      return ProductCatalogSummary(totalCount: countResponse.count, lastUpdatedAt: lastUpdatedAt);
    } catch (error) {
      if (kDebugMode) print('讀取商品目錄概況失敗: $error');
      return const ProductCatalogSummary(totalCount: 0, lastUpdatedAt: null);
    }
  }
}
