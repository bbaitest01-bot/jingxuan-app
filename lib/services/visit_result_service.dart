import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/visit_chart.dart';
import '../models/visit_project.dart';
import '../models/visit_result.dart';
import 'visit_project_service.dart';

/// 專案拜訪結果的讀寫（資料表 visit_results，4-2b）。
/// 權限由資料庫 RLS 保證「只能讀寫自己的，專案、客戶、拜訪紀錄也必須是自己的」；
/// 客戶狀態由資料庫觸發器自動改成最新一筆結果，這裡不用自己更新客戶。
/// 離線預覽模式存在記憶體，並模擬觸發器更新 OfflineDataStore 的客戶狀態。
class VisitResultService {
  static final VisitResultService instance = VisitResultService._internal();
  VisitResultService._internal();

  // 讀結果時一起帶出專案名稱、客戶名字、連結的拜訪紀錄標題
  static const String _selectColumns =
      '*, visit_projects(title), customers(name), visit_records(title, deleted_at)';

  final List<VisitResult> _offlineResults = [];
  int _offlineSequence = 0;

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId {
    if (isOfflineMode) return null;
    return _supabase.auth.currentUser?.id;
  }

  /// 自己的拜訪結果，新的在前；[projectId] 有值時只列該專案；最多 [limit] 筆
  Future<List<VisitResult>> fetchMyResults({String? projectId, int limit = 50}) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      final List<VisitResult> results = _offlineResults.where((result) {
        return projectId == null || result.projectId == projectId;
      }).toList();
      results.sort(VisitResult.compareNewestFirst);
      return results.take(limit).toList();
    }

    var query = _supabase.from('visit_results').select(_selectColumns).eq('profile_id', userId);
    if (projectId != null) query = query.eq('project_id', projectId);
    final List<dynamic> rows = await query
        .order('visited_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    final List<VisitResult> results = [];
    for (final dynamic row in rows) {
      results.add(VisitResult.fromJson(row as Map<String, dynamic>));
    }
    return results;
  }

  /// 成效圖表用：[from]～[to]（含）之間自己的結果，帶出客戶標籤（4-2d）
  Future<List<VisitChartPoint>> fetchChartPoints(DateTime from, DateTime to) async {
    final String? userId = _currentUserId;
    if (userId == null) return _offlineChartPoints(from, to);

    final List<dynamic> rows = await _supabase
        .from('visit_results')
        .select('visited_on, result, project_id, customers(tags)')
        .eq('profile_id', userId)
        .gte('visited_on', VisitProjectService.formatDateForDatabase(from))
        .lte('visited_on', VisitProjectService.formatDateForDatabase(to));
    final List<VisitChartPoint> points = [];
    for (final dynamic row in rows) {
      final Map<String, dynamic> map = row as Map<String, dynamic>;
      final Map<String, dynamic>? customer = map['customers'] as Map<String, dynamic>?;
      final DateTime visitedOn = DateTime.tryParse(map['visited_on']?.toString() ?? '') ?? DateTime.now();
      points.add(VisitChartPoint(
        visitedOn: DateTime(visitedOn.year, visitedOn.month, visitedOn.day),
        result: map['result']?.toString() ?? '',
        projectId: map['project_id']?.toString() ?? '',
        customerTags: _tagsOf(customer?['tags']),
      ));
    }
    return points;
  }

  static List<String> _tagsOf(dynamic tags) {
    if (tags is! List) return [];
    final List<String> names = [];
    for (final dynamic tag in tags) {
      names.add(tag.toString());
    }
    return names;
  }

  List<VisitChartPoint> _offlineChartPoints(DateTime from, DateTime to) {
    final Map<String, List<String>> tagsByCustomer = {};
    for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
      tagsByCustomer[customer['id'].toString()] = _tagsOf(customer['tags']);
    }
    final List<VisitChartPoint> points = [];
    for (final VisitResult result in _offlineResults) {
      if (result.visitedOn.isBefore(from) || result.visitedOn.isAfter(to)) continue;
      points.add(VisitChartPoint(
        visitedOn: result.visitedOn,
        result: result.result,
        projectId: result.projectId,
        customerTags: tagsByCustomer[result.customerId] ?? const [],
      ));
    }
    return points;
  }

  /// 客戶狀態的來源：這位客戶最新一筆結果（沒有結果回傳 null）
  Future<ClientStatusSource?> fetchStatusSource(String customerId) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      final List<VisitResult> mine = _offlineResults.where((result) => result.customerId == customerId).toList();
      if (mine.isEmpty) return null;
      mine.sort(VisitResult.compareNewestFirst);
      return ClientStatusSource(result: mine.first.result, projectTitle: mine.first.projectTitle, visitedOn: mine.first.visitedOn);
    }

    final Map<String, dynamic>? row = await _supabase
        .from('visit_results')
        .select('result, visited_on, visit_projects(title)')
        .eq('profile_id', userId)
        .eq('customer_id', customerId)
        .order('visited_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final Map<String, dynamic>? project = row['visit_projects'] as Map<String, dynamic>?;
    final DateTime visitedOn = DateTime.tryParse(row['visited_on']?.toString() ?? '') ?? DateTime.now();
    return ClientStatusSource(
      result: row['result']?.toString() ?? '',
      projectTitle: project?['title']?.toString() ?? '',
      visitedOn: DateTime(visitedOn.year, visitedOn.month, visitedOn.day),
    );
  }

  /// 檢查填寫內容，有問題回傳錯誤訊息，沒問題回傳 null
  static String? validateDraft(VisitResultDraft draft, DateTime today) {
    if (draft.projectId.isEmpty) return '請選擇專案';
    if (draft.customerId.isEmpty) return '請選擇客戶';
    final String? result = draft.result;
    if (result == null || !VisitResult.resultOptions.contains(result)) return '請選擇拜訪結果 ✔、△ 或 ✖';
    // 只比日期、不比時間（預設日期是「現在」，帶著幾點幾分）
    final DateTime day = DateTime(today.year, today.month, today.day);
    final DateTime visitedDay = DateTime(draft.visitedOn.year, draft.visitedOn.month, draft.visitedOn.day);
    if (visitedDay.isAfter(day)) return '拜訪日期不能是未來';
    if (draft.note.trim().length > VisitResult.maxNoteLength) return '備註最多 ${VisitResult.maxNoteLength} 字';
    return null;
  }

  /// 記錄一筆拜訪
  Future<void> createResult(VisitResultDraft draft) async {
    final String? problem = validateDraft(draft, DateTime.now());
    if (problem != null) throw Exception(problem);

    final String? userId = _currentUserId;
    if (userId == null) {
      final String? eventId = draft.scheduleEventId;
      if (eventId != null && _offlineResults.any((result) => result.scheduleEventId == eventId)) {
        throw Exception('這個行程已經記錄過結果，請到「已記錄」修改');
      }
      _offlineSequence++;
      _offlineResults.add(_offlineResultFromDraft('offline-result-$_offlineSequence', draft, DateTime.now()));
      _refreshOfflineCustomerStatus(draft.customerId);
      return;
    }
    try {
      await _supabase.from('visit_results').insert({
        'profile_id': userId,
        ..._draftToRow(draft),
        'schedule_event_id': draft.scheduleEventId,
      });
    } on PostgrestException catch (error) {
      // 23505＝違反唯一限制：同一個行程只能有一筆結果（可能在別的分頁剛記過）
      if (error.code == '23505') throw Exception('這個行程已經記錄過結果，請到「已記錄」修改');
      rethrow;
    }
  }

  /// 讀一筆完整的拜訪結果（從行程或待記錄清單按「修改」時用）；找不到回傳 null
  Future<VisitResult?> fetchResult(String id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      for (final VisitResult result in _offlineResults) {
        if (result.id == id) return result;
      }
      return null;
    }
    final Map<String, dynamic>? row = await _supabase
        .from('visit_results')
        .select(_selectColumns)
        .eq('id', id)
        .eq('profile_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return VisitResult.fromJson(row);
  }

  /// 某個行程記過的結果（一個行程最多一筆）；沒有回傳 null
  Future<VisitResult?> fetchResultForEvent(String eventId) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      for (final VisitResult result in _offlineResults) {
        if (result.scheduleEventId == eventId) return result;
      }
      return null;
    }
    final Map<String, dynamic>? row = await _supabase
        .from('visit_results')
        .select(_selectColumns)
        .eq('profile_id', userId)
        .eq('schedule_event_id', eventId)
        .maybeSingle();
    if (row == null) return null;
    return VisitResult.fromJson(row);
  }

  /// 修改一筆拜訪結果
  Future<void> updateResult(VisitResult original, VisitResultDraft draft) async {
    final String? problem = validateDraft(draft, DateTime.now());
    if (problem != null) throw Exception(problem);

    final String? userId = _currentUserId;
    if (userId == null) {
      final int index = _offlineResults.indexWhere((result) => result.id == original.id);
      if (index < 0) return;
      // 修改時保留原本來自哪個行程
      final VisitResultDraft keepEvent = VisitResultDraft(
        projectId: draft.projectId,
        projectTitle: draft.projectTitle,
        customerId: draft.customerId,
        customerName: draft.customerName,
        visitedOn: draft.visitedOn,
        result: draft.result,
        note: draft.note,
        visitRecordId: draft.visitRecordId,
        visitRecordTitle: draft.visitRecordTitle,
        scheduleEventId: original.scheduleEventId,
      );
      _offlineResults[index] = _offlineResultFromDraft(original.id, keepEvent, original.createdAt);
      _refreshOfflineCustomerStatus(original.customerId);
      _refreshOfflineCustomerStatus(draft.customerId);
      return;
    }
    await _supabase.from('visit_results').update(_draftToRow(draft)).eq('id', original.id).eq('profile_id', userId);
  }

  /// 刪除一筆拜訪結果；客戶狀態會改回上一筆（沒有就變未設定）
  Future<void> deleteResult(VisitResult result) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _offlineResults.removeWhere((item) => item.id == result.id);
      _refreshOfflineCustomerStatus(result.customerId);
      return;
    }
    await _supabase.from('visit_results').delete().eq('id', result.id).eq('profile_id', userId);
  }

  Map<String, dynamic> _draftToRow(VisitResultDraft draft) {
    final String note = draft.note.trim();
    return {
      'project_id': draft.projectId,
      'customer_id': draft.customerId,
      'visited_on': VisitProjectService.formatDateForDatabase(draft.visitedOn),
      'result': draft.result,
      'note': note.isEmpty ? null : note,
      'visit_record_id': draft.visitRecordId,
    };
  }

  // ---------------------------------------------------------------------------
  // 離線預覽
  // ---------------------------------------------------------------------------

  /// 離線預覽：給專案進度計算用的結果摘要
  List<VisitResultSummary> offlineSummariesSince(DateTime fromDate) {
    final List<VisitResultSummary> summaries = [];
    for (final VisitResult result in _offlineResults) {
      if (result.visitedOn.isBefore(fromDate)) continue;
      summaries.add(VisitResultSummary(
        projectId: result.projectId,
        customerId: result.customerId,
        visitedOn: result.visitedOn,
        result: result.result,
      ));
    }
    return summaries;
  }

  /// 離線預覽：專案刪除時一起刪掉它的結果（資料庫是自動連帶刪除）
  void removeOfflineResultsOfProject(String projectId) {
    final Set<String> customerIds = {};
    for (final VisitResult result in _offlineResults) {
      if (result.projectId == projectId) customerIds.add(result.customerId);
    }
    _offlineResults.removeWhere((result) => result.projectId == projectId);
    for (final String customerId in customerIds) {
      _refreshOfflineCustomerStatus(customerId);
    }
  }

  int countOfflineResultsOfProject(String projectId) {
    return _offlineResults.where((result) => result.projectId == projectId).length;
  }

  VisitResult _offlineResultFromDraft(String id, VisitResultDraft draft, DateTime createdAt) {
    final String note = draft.note.trim();
    return VisitResult(
      id: id,
      projectId: draft.projectId,
      projectTitle: draft.projectTitle,
      customerId: draft.customerId,
      customerName: draft.customerName,
      visitedOn: DateTime(draft.visitedOn.year, draft.visitedOn.month, draft.visitedOn.day),
      result: draft.result ?? VisitResult.resultConsidering,
      note: note,
      visitRecordId: draft.visitRecordId,
      visitRecordTitle: draft.visitRecordTitle,
      scheduleEventId: draft.scheduleEventId,
      createdAt: createdAt,
    );
  }

  // 模擬資料庫觸發器：客戶狀態＝最新一筆結果，沒有結果就清空
  void _refreshOfflineCustomerStatus(String customerId) {
    final List<VisitResult> mine = _offlineResults.where((result) => result.customerId == customerId).toList();
    mine.sort(VisitResult.compareNewestFirst);
    String? latestResult;
    if (mine.isNotEmpty) latestResult = mine.first.result;
    for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
      if (customer['id'].toString() == customerId) customer['client_status'] = latestResult;
    }
  }

  /// 測試用：清空離線暫存
  void resetOfflineForTest() {
    _offlineResults.clear();
    _offlineSequence = 0;
  }
}
