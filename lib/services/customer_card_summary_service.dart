import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'customer_stage_service.dart';

/// 客戶卡片上的兩行摘要：保單狀況、下次行程（2026-10-30 沛沛選卡片 C：卡片不空也不擠）；
/// 2026-11-01 點開後飛出來的放大卡片，名字下面多一行介紹人
class CustomerCardSummary {
  final String stage;
  final int activePolicyCount;
  final DateTime? nextEventAt;
  final String? nextEventTitle;

  /// 介紹這位客戶的人（客戶資料的「轉介紹來源」）
  final String? referrerName;

  const CustomerCardSummary({
    required this.stage,
    required this.activePolicyCount,
    this.nextEventAt,
    this.nextEventTitle,
    this.referrerName,
  });

  /// 「保戶・3 張有效保單」「跟進中・尚無有效保單」「未開發」
  String get policyText {
    final String stageLabel = CustomerStage.label(stage);
    if (activePolicyCount > 0) return '$stageLabel・$activePolicyCount 張有效保單';
    if (stage == CustomerStage.lead) return stageLabel;
    return '$stageLabel・尚無有效保單';
  }

  /// 「今天 10:30 醫療險需求訪談」「明天 10:00 保單送件」「11/3 14:00 …」；沒有行程回傳「尚無行程」
  String nextEventText(String customerName, DateTime now) {
    final DateTime? eventAt = nextEventAt;
    if (eventAt == null) return '尚無行程';
    final DateTime local = eventAt.toLocal();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int dayDifference = DateTime(local.year, local.month, local.day).difference(today).inDays;
    String dayText = '${local.month}/${local.day}';
    if (dayDifference == 0) dayText = '今天';
    if (dayDifference == 1) dayText = '明天';
    final String time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    // 行程標題常常以客戶名字開頭（例：「王大明 保單送件」），卡片上已經有名字，去掉比較短
    String title = nextEventTitle ?? '';
    if (customerName.isNotEmpty && title.startsWith(customerName)) title = title.substring(customerName.length).trim();
    return '$dayText $time $title'.trim();
  }
}

/// 讀所有客戶卡片的摘要。客戶管理讀客戶時呼叫 [refresh]，卡片聽 [summaries] 自己更新
class CustomerCardSummaryService {
  static final CustomerCardSummaryService instance = CustomerCardSummaryService._internal();
  CustomerCardSummaryService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 客戶編號 → 卡片摘要
  final ValueNotifier<Map<String, CustomerCardSummary>> summaries = ValueNotifier(const {});

  Future<void> refresh() async {
    if (isOfflineMode) return;
    final User? user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      // 權限只會給自己名下客戶的保單
      final List<dynamic> policyRows =
          await _supabase.from('customer_policies').select('customer_id').eq('status', 'active');
      final List<dynamic> visitResultRows =
          await _supabase.from('visit_results').select('customer_id').eq('profile_id', user.id);
      final List<dynamic> scheduleRows = await _supabase
          .from('schedule_events')
          .select('customer_id, title, start_at, is_completed')
          .eq('profile_id', user.id)
          .isFilter('deleted_at', null)
          .not('customer_id', 'is', null)
          .order('start_at');
      final List<dynamic> customerRows =
          await _supabase.from('customers').select('id, name, referral_source_id').eq('profile_id', user.id);
      summaries.value = _buildSummaries(policyRows, visitResultRows, scheduleRows, customerRows, DateTime.now());
    } catch (error) {
      if (kDebugMode) print('讀客戶卡片摘要失敗: $error');
    }
  }

  static Map<String, CustomerCardSummary> _buildSummaries(
    List<dynamic> policyRows,
    List<dynamic> visitResultRows,
    List<dynamic> scheduleRows,
    List<dynamic> customerRows,
    DateTime now,
  ) {
    final Map<String, int> policyCountByCustomer = {};
    for (final dynamic row in policyRows) {
      final String customerId = row['customer_id'].toString();
      policyCountByCustomer[customerId] = (policyCountByCustomer[customerId] ?? 0) + 1;
    }
    // 有拜訪結果或有排行程＝跟進過（和客戶階段的規則一樣）
    final Set<String> followedCustomerIds = {};
    for (final dynamic row in visitResultRows) {
      followedCustomerIds.add(row['customer_id'].toString());
    }
    final Map<String, Map<String, dynamic>> nextEventByCustomer = {};
    for (final dynamic row in scheduleRows) {
      final String customerId = row['customer_id'].toString();
      followedCustomerIds.add(customerId);
      final DateTime? startAt = DateTime.tryParse(row['start_at']?.toString() ?? '');
      final bool isUpcoming = startAt != null && startAt.isAfter(now) && row['is_completed'] != true;
      // 依開始時間排好了，第一個還沒到的就是下次行程
      if (isUpcoming && !nextEventByCustomer.containsKey(customerId)) {
        nextEventByCustomer[customerId] = Map<String, dynamic>.from(row as Map);
      }
    }

    final Map<String, String> referrerByCustomer = _referrerNames(customerRows);

    final Set<String> allCustomerIds = {
      ...policyCountByCustomer.keys,
      ...followedCustomerIds,
      ...referrerByCustomer.keys,
    };
    final Map<String, CustomerCardSummary> result = {};
    for (final String customerId in allCustomerIds) {
      final int policyCount = policyCountByCustomer[customerId] ?? 0;
      final Map<String, dynamic> nextEvent = nextEventByCustomer[customerId] ?? const {};
      result[customerId] = CustomerCardSummary(
        stage: CustomerStage.classify(
          hasActivePolicy: policyCount > 0,
          hasVisitActivity: followedCustomerIds.contains(customerId),
        ),
        activePolicyCount: policyCount,
        nextEventAt: DateTime.tryParse(nextEvent['start_at']?.toString() ?? ''),
        nextEventTitle: nextEvent['title']?.toString(),
        referrerName: referrerByCustomer[customerId],
      );
    }
    return result;
  }

  // 客戶編號 → 介紹人名字（介紹人要是自己名下的客戶才找得到）
  static Map<String, String> _referrerNames(List<dynamic> customerRows) {
    final Map<String, String> nameById = {};
    for (final dynamic row in customerRows) {
      nameById[row['id'].toString()] = row['name']?.toString() ?? '';
    }
    final Map<String, String> result = {};
    for (final dynamic row in customerRows) {
      final String? referrerId = row['referral_source_id']?.toString();
      final String referrerName = nameById[referrerId] ?? '';
      if (referrerName.isNotEmpty) result[row['id'].toString()] = referrerName;
    }
    return result;
  }

  /// 沒有任何保單、拜訪、行程的客戶＝未開發
  CustomerCardSummary summaryOf(String customerId) {
    return summaries.value[customerId] ?? const CustomerCardSummary(stage: CustomerStage.lead, activePolicyCount: 0);
  }
}
