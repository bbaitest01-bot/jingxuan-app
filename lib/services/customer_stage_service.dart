import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 客戶階段的代號與畫面名稱（數據戰情摘要、客戶管理篩選共用）
///
/// 規則（2026-10-23 沛沛確認，第 5 階段選項 B）：
/// - 保戶：有「有效」保單
/// - 跟進中：沒有有效保單，但有拜訪結果，或有排了這位客戶的行程
/// - 未開發：以上都沒有
/// 不看標籤、備註裡的文字（舊規則容易誤判，例如備註寫「不要再拜訪」也被算成跟進中）。
class CustomerStage {
  static const String client = 'client';
  static const String prospect = 'prospect';
  static const String lead = 'lead';

  /// 畫面上的順序
  static const List<String> all = [client, prospect, lead];

  static String label(String stage) {
    if (stage == client) {
      return '保戶';
    }
    if (stage == prospect) {
      return '跟進中';
    }
    return '未開發';
  }

  /// 網址參數對得上才算數，對不上就當作沒有篩選
  static bool isValid(String? stage) {
    return stage != null && all.contains(stage);
  }

  /// 依兩個條件決定階段：有效保單優先，其次是拜訪紀錄
  static String classify({required bool hasActivePolicy, required bool hasVisitActivity}) {
    if (hasActivePolicy) {
      return client;
    }
    if (hasVisitActivity) {
      return prospect;
    }
    return lead;
  }
}

/// 三個階段各有幾位客戶
class CustomerStageSummary {
  final int totalCustomers;
  final int clientCount;
  final int prospectCount;
  final int leadCount;

  const CustomerStageSummary({
    required this.totalCustomers,
    required this.clientCount,
    required this.prospectCount,
    required this.leadCount,
  });

  int countOf(String stage) {
    if (stage == CustomerStage.client) {
      return clientCount;
    }
    if (stage == CustomerStage.prospect) {
      return prospectCount;
    }
    return leadCount;
  }
}

/// 算出每位客戶的階段（只算自己名下、不在垃圾桶的客戶）
class CustomerStageService {
  static final CustomerStageService _instance = CustomerStageService._internal();
  factory CustomerStageService() => _instance;
  CustomerStageService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 回傳「客戶編號 → 階段」；離線模式或還沒登入時回傳空的
  Future<Map<String, String>> fetchStageByCustomerId() async {
    if (isOfflineMode) return {};
    final User? user = _supabase.auth.currentUser;
    if (user == null) return {};

    try {
      final List<dynamic> customerRows = await _supabase
          .from('customers')
          .select('id')
          .eq('profile_id', user.id)
          .isFilter('deleted_at', null);
      // 權限只會給自己名下客戶的保單；這裡只要有效的
      final List<dynamic> activePolicyRows =
          await _supabase.from('customer_policies').select('customer_id').eq('status', 'active');
      final List<dynamic> visitResultRows =
          await _supabase.from('visit_results').select('customer_id').eq('profile_id', user.id);
      final List<dynamic> scheduleRows = await _supabase
          .from('schedule_events')
          .select('customer_id')
          .eq('profile_id', user.id)
          .isFilter('deleted_at', null)
          .not('customer_id', 'is', null);

      final Set<String> activePolicyCustomerIds = _customerIdsIn(activePolicyRows);
      final Set<String> visitedCustomerIds = _customerIdsIn(visitResultRows);
      visitedCustomerIds.addAll(_customerIdsIn(scheduleRows));

      final Map<String, String> stageByCustomerId = {};
      for (final dynamic row in customerRows) {
        final String customerId = row['id'].toString();
        stageByCustomerId[customerId] = CustomerStage.classify(
          hasActivePolicy: activePolicyCustomerIds.contains(customerId),
          hasVisitActivity: visitedCustomerIds.contains(customerId),
        );
      }
      return stageByCustomerId;
    } catch (error) {
      if (kDebugMode) print('計算客戶階段失敗: $error');
      return {};
    }
  }

  /// 把「客戶編號 → 階段」數成三個數字
  static CustomerStageSummary summarize(Map<String, String> stageByCustomerId) {
    int clientCount = 0;
    int prospectCount = 0;
    int leadCount = 0;
    for (final String stage in stageByCustomerId.values) {
      if (stage == CustomerStage.client) {
        clientCount++;
      } else if (stage == CustomerStage.prospect) {
        prospectCount++;
      } else {
        leadCount++;
      }
    }
    return CustomerStageSummary(
      totalCustomers: stageByCustomerId.length,
      clientCount: clientCount,
      prospectCount: prospectCount,
      leadCount: leadCount,
    );
  }

  /// 客戶管理用：只留下某個階段的客戶；網址沒帶有效的階段時原樣回傳
  static List<Map<String, dynamic>> filterByStage(
    List<Map<String, dynamic>> customers,
    Map<String, String> stageByCustomerId,
    String? stage,
  ) {
    if (!CustomerStage.isValid(stage)) {
      return customers;
    }
    final List<Map<String, dynamic>> matchedCustomers = [];
    for (final Map<String, dynamic> customer in customers) {
      if (stageByCustomerId[customer['id']?.toString()] == stage) {
        matchedCustomers.add(customer);
      }
    }
    return matchedCustomers;
  }

  /// 從查詢結果收集不重複的客戶編號
  static Set<String> _customerIdsIn(List<dynamic> rows) {
    final Set<String> customerIds = {};
    for (final dynamic row in rows) {
      final dynamic customerId = row['customer_id'];
      if (customerId != null) {
        customerIds.add(customerId.toString());
      }
    }
    return customerIds;
  }
}
