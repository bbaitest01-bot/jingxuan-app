import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/visit_result.dart';
import 'visit_result_service.dart';

/// 一個「有客戶、時間已到」的行程，以及它的拜訪結果狀態（4-2c）
class PendingVisitEvent {
  final String eventId;
  final String title;
  final DateTime startAt;
  final String customerId;
  final String customerName;
  // 按過「沒拜訪」
  final bool isSkipped;
  // 已記錄的結果（還沒記錄是 null）
  final String? resultId;
  final String? result;

  const PendingVisitEvent({
    required this.eventId,
    required this.title,
    required this.startAt,
    required this.customerId,
    required this.customerName,
    this.isSkipped = false,
    this.resultId,
    this.result,
  });

  bool get isRecorded => resultId != null;
  bool get isPending => !isRecorded && !isSkipped;
}

/// 兩個清單：還沒記錄結果、最近已處理（記錄過或標了沒拜訪）
class PendingVisitLists {
  final List<PendingVisitEvent> pending;
  final List<PendingVisitEvent> recentlyDone;

  const PendingVisitLists({required this.pending, required this.recentlyDone});

  bool get isEmpty => pending.isEmpty && recentlyDone.isEmpty;
}

/// 「還沒記錄結果」的行程（設計見全景地圖 4-G）：
/// 自己的、有客戶、未刪除、開始時間在最近 30 天到現在、沒標「沒拜訪」、沒有對應的拜訪結果。
/// 已處理的只列最近 7 天，方便修改或復原。
class VisitPendingService {
  static final VisitPendingService instance = VisitPendingService._internal();
  VisitPendingService._internal();

  static const int pendingDays = 30;
  static const int recentDoneDays = 7;

  // 離線預覽：按過「沒拜訪」的行程編號
  final Set<String> _offlineSkippedIds = {};

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId {
    if (isOfflineMode) return null;
    return _supabase.auth.currentUser?.id;
  }

  Future<PendingVisitLists> fetchLists(DateTime now) async {
    final List<PendingVisitEvent> events = await _fetchStartedCustomerEvents(now);
    final DateTime recentFrom = now.subtract(const Duration(days: recentDoneDays));
    final List<PendingVisitEvent> pending = [];
    final List<PendingVisitEvent> recentlyDone = [];
    for (final PendingVisitEvent event in events) {
      if (event.isPending) {
        pending.add(event);
      } else if (!event.startAt.isBefore(recentFrom)) {
        recentlyDone.add(event);
      }
    }
    // 新的在上面
    pending.sort((a, b) => b.startAt.compareTo(a.startAt));
    recentlyDone.sort((a, b) => b.startAt.compareTo(a.startAt));
    return PendingVisitLists(pending: pending, recentlyDone: recentlyDone);
  }

  /// 一個行程目前的狀態（今日行程的行程視窗用）；不是有客戶、時間已到的行程回傳 null
  Future<PendingVisitEvent?> fetchEventStatus(String eventId, DateTime now) async {
    final List<PendingVisitEvent> events = await _fetchStartedCustomerEvents(now, onlyEventId: eventId);
    if (events.isEmpty) return null;
    return events.first;
  }

  // 讀「自己的、有客戶、未刪除、最近 30 天到現在」的行程，順便帶出客戶名字與拜訪結果
  Future<List<PendingVisitEvent>> _fetchStartedCustomerEvents(DateTime now, {String? onlyEventId}) async {
    final DateTime from = now.subtract(const Duration(days: pendingDays));
    final String? userId = _currentUserId;
    if (userId == null) return _offlineEvents(from, now, onlyEventId);

    var query = _supabase
        .from('schedule_events')
        .select('id, title, start_at, customer_id, visit_skipped_at, customers(name, deleted_at), visit_results(id, result)')
        .eq('profile_id', userId)
        .not('customer_id', 'is', null)
        .isFilter('deleted_at', null)
        .gte('start_at', from.toUtc().toIso8601String())
        .lte('start_at', now.toUtc().toIso8601String());
    if (onlyEventId != null) query = query.eq('id', onlyEventId);
    final List<dynamic> rows = await query;

    final List<PendingVisitEvent> events = [];
    for (final dynamic row in rows) {
      final PendingVisitEvent? event = _fromRow(row as Map<String, dynamic>);
      if (event != null) events.add(event);
    }
    return events;
  }

  PendingVisitEvent? _fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic>? customer = row['customers'] as Map<String, dynamic>?;
    // 客戶已放進垃圾桶的行程不列（還原後會再出現）
    if (customer == null || customer['deleted_at'] != null) return null;
    final List<dynamic> results = row['visit_results'] as List<dynamic>? ?? [];
    String? resultId;
    String? result;
    if (results.isNotEmpty) {
      final Map<String, dynamic> first = results.first as Map<String, dynamic>;
      resultId = first['id']?.toString();
      result = first['result']?.toString();
    }
    final DateTime startAt = DateTime.tryParse(row['start_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return PendingVisitEvent(
      eventId: row['id'].toString(),
      title: row['title']?.toString() ?? '',
      startAt: startAt,
      customerId: row['customer_id'].toString(),
      customerName: customer['name']?.toString() ?? '',
      isSkipped: row['visit_skipped_at'] != null,
      resultId: resultId,
      result: result,
    );
  }

  /// 標記「沒拜訪」：移出待記錄清單，不算進度、不改客戶狀態
  Future<void> markSkipped(String eventId) => _setSkipped(eventId, true);

  /// 復原「沒拜訪」：回到待記錄清單
  Future<void> undoSkipped(String eventId) => _setSkipped(eventId, false);

  Future<void> _setSkipped(String eventId, bool isSkipped) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      if (isSkipped) {
        _offlineSkippedIds.add(eventId);
      } else {
        _offlineSkippedIds.remove(eventId);
      }
      return;
    }
    final String? skippedAt = isSkipped ? DateTime.now().toUtc().toIso8601String() : null;
    await _supabase
        .from('schedule_events')
        .update({'visit_skipped_at': skippedAt})
        .eq('id', eventId)
        .eq('profile_id', userId);
  }

  // 離線預覽：從暫存的行程與離線拜訪結果組出清單
  Future<List<PendingVisitEvent>> _offlineEvents(DateTime from, DateTime now, String? onlyEventId) async {
    final Map<String, String> customerNames = {};
    for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
      if (customer['deleted_at'] != null) continue;
      customerNames[customer['id'].toString()] = customer['name']?.toString() ?? '';
    }

    final List<PendingVisitEvent> events = [];
    for (final Map<String, dynamic> row in OfflineDataStore.scheduleEvents) {
      final String eventId = row['id'].toString();
      if (onlyEventId != null && eventId != onlyEventId) continue;
      if (row['deleted_at'] != null) continue;
      final String customerId = row['customer_id']?.toString() ?? '';
      final String? customerName = customerNames[customerId];
      if (customerName == null) continue;
      final DateTime? startAt = DateTime.tryParse(row['start_at']?.toString() ?? '')?.toLocal();
      if (startAt == null || startAt.isBefore(from) || startAt.isAfter(now)) continue;

      final VisitResult? recorded = await VisitResultService.instance.fetchResultForEvent(eventId);
      events.add(PendingVisitEvent(
        eventId: eventId,
        title: row['title']?.toString() ?? '',
        startAt: startAt,
        customerId: customerId,
        customerName: customerName,
        isSkipped: _offlineSkippedIds.contains(eventId),
        resultId: recorded?.id,
        result: recorded?.result,
      ));
    }
    return events;
  }

  /// 測試用：清空離線暫存
  void resetOfflineForTest() => _offlineSkippedIds.clear();
}
