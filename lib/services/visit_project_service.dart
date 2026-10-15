import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/visit_project.dart';

/// 建立或修改專案時填的內容
class VisitProjectDraft {
  final String title;
  final String purpose;
  final String periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int targetCount;
  // 名單：客戶編號 → 客戶名字（空＝任何客戶都算）
  final Map<String, String> members;

  const VisitProjectDraft({
    required this.title,
    this.purpose = '',
    required this.periodType,
    this.startDate,
    this.endDate,
    required this.targetCount,
    this.members = const {},
  });
}

/// 專案拜訪的讀寫（資料表 visit_projects、visit_project_customers、visit_results）。
/// 權限由資料庫 RLS 保證「只能讀寫自己的」；這裡查詢時也一律加上自己的 profile_id。
/// 離線預覽模式存在記憶體，重新整理就清空。
class VisitProjectService {
  static final VisitProjectService instance = VisitProjectService._internal();
  VisitProjectService._internal();

  // 讀專案時一起帶出名單與客戶名字
  static const String _selectColumns = '*, visit_project_customers(customer_id, customers(name, deleted_at))';

  // 離線預覽模式用的暫存
  final List<VisitProject> _offlineProjects = [];
  int _offlineSequence = 0;

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId {
    if (isOfflineMode) return null;
    return _supabase.auth.currentUser?.id;
  }

  /// 自己的專案：「日常拜訪」排第一，其餘新到舊。沒有日常拜訪時先自動建立
  Future<List<VisitProject>> fetchMyProjects() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _ensureOfflineDefaultProject();
      return _sortProjects(List<VisitProject>.from(_offlineProjects));
    }

    await _ensureDefaultProject(userId);
    final List<dynamic> rows = await _supabase
        .from('visit_projects')
        .select(_selectColumns)
        .eq('profile_id', userId)
        .order('created_at', ascending: false);

    final List<VisitProject> projects = [];
    for (final dynamic row in rows) {
      projects.add(VisitProject.fromJson(row as Map<String, dynamic>));
    }
    return _sortProjects(projects);
  }

  List<VisitProject> _sortProjects(List<VisitProject> projects) {
    final List<VisitProject> defaults = projects.where((project) => project.isDefault).toList();
    final List<VisitProject> others = projects.where((project) => !project.isDefault).toList();
    others.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...defaults, ...others];
  }

  // 每人一個「日常拜訪」（每月 20 次）；資料庫有唯一限制，兩個分頁同時建立時第二個會失敗，當作已存在
  Future<void> _ensureDefaultProject(String userId) async {
    final Map<String, dynamic>? existing = await _supabase
        .from('visit_projects')
        .select('id')
        .eq('profile_id', userId)
        .eq('is_default', true)
        .maybeSingle();
    if (existing != null) return;

    try {
      await _supabase.from('visit_projects').insert({
        'profile_id': userId,
        'title': VisitProject.defaultTitle,
        'purpose': '',
        'period_type': VisitProject.periodMonth,
        'target_count': VisitProject.defaultTargetCount,
        'is_default': true,
      });
    } on PostgrestException catch (error) {
      // 23505＝違反唯一限制：別的分頁剛建好，不用再建
      if (error.code != '23505') rethrow;
    }
  }

  void _ensureOfflineDefaultProject() {
    final bool hasDefault = _offlineProjects.any((project) => project.isDefault);
    if (hasDefault) return;
    _offlineProjects.add(VisitProject(
      id: 'offline-project-default',
      title: VisitProject.defaultTitle,
      periodType: VisitProject.periodMonth,
      targetCount: VisitProject.defaultTargetCount,
      isDefault: true,
      createdAt: DateTime.now(),
    ));
  }

  /// 自己從某天起的拜訪結果（算各專案這一期的進度用）
  Future<List<VisitResultSummary>> fetchResultsSince(DateTime fromDate) async {
    final String? userId = _currentUserId;
    if (userId == null) return [];

    final List<dynamic> rows = await _supabase
        .from('visit_results')
        .select('project_id, customer_id, visited_on, result')
        .eq('profile_id', userId)
        .gte('visited_on', formatDateForDatabase(fromDate));
    final List<VisitResultSummary> results = [];
    for (final dynamic row in rows) {
      results.add(VisitResultSummary.fromJson(row as Map<String, dynamic>));
    }
    return results;
  }

  /// 所有專案「這一期」最早的開始日，只讀這天之後的結果就夠了
  static DateTime earliestPeriodStart(List<VisitProject> projects, DateTime today) {
    DateTime earliest = DateTime(today.year, today.month, today.day);
    for (final VisitProject project in projects) {
      final DateTime start = project.currentPeriod(today).start;
      if (start.isBefore(earliest)) earliest = start;
    }
    return earliest;
  }

  /// 檢查填寫內容，有問題回傳錯誤訊息，沒問題回傳 null
  static String? validateDraft(VisitProjectDraft draft) {
    if (draft.title.trim().isEmpty) return '請輸入專案名稱';
    if (draft.title.trim().length > 50) return '專案名稱最多 50 字';
    if (draft.targetCount < 1) return '目標次數至少 1 次';
    if (draft.targetCount > VisitProject.maxTargetCount) return '目標次數最多 ${VisitProject.maxTargetCount} 次';
    if (draft.periodType == VisitProject.periodRange) {
      final DateTime? start = draft.startDate;
      final DateTime? end = draft.endDate;
      if (start == null || end == null) return '請選擇開始日和結束日';
      if (end.isBefore(start)) return '結束日不能早於開始日';
    }
    return null;
  }

  /// 建立專案（含名單）
  Future<void> createProject(VisitProjectDraft draft) async {
    final String? problem = validateDraft(draft);
    if (problem != null) throw Exception(problem);

    final String? userId = _currentUserId;
    if (userId == null) {
      _offlineSequence++;
      _offlineProjects.add(_offlineProjectFromDraft('offline-project-$_offlineSequence', draft, isDefault: false));
      return;
    }

    final Map<String, dynamic> row = await _supabase
        .from('visit_projects')
        .insert({'profile_id': userId, ..._draftToRow(draft)})
        .select('id')
        .single();
    await _replaceMembers(row['id'].toString(), draft.members.keys.toSet(), existingIds: {});
  }

  /// 修改專案；「日常拜訪」的名稱與名單不能改，只改週期與目標
  Future<void> updateProject(VisitProject project, VisitProjectDraft draft) async {
    final String? problem = validateDraft(draft);
    if (problem != null) throw Exception(problem);

    final String? userId = _currentUserId;
    if (userId == null) {
      final int index = _offlineProjects.indexWhere((item) => item.id == project.id);
      if (index < 0) return;
      _offlineProjects[index] = _offlineProjectFromDraft(project.id, draft, isDefault: project.isDefault);
      return;
    }

    final Map<String, dynamic> row = _draftToRow(draft);
    if (project.isDefault) {
      row.remove('title');
      row.remove('purpose');
    }
    await _supabase.from('visit_projects').update(row).eq('id', project.id).eq('profile_id', userId);
    if (!project.isDefault) {
      await _replaceMembers(project.id, draft.members.keys.toSet(), existingIds: project.members.keys.toSet());
    }
  }

  /// 這個專案底下有幾筆拜訪結果（刪除前提示用）
  Future<int> countResults(String projectId) async {
    final String? userId = _currentUserId;
    if (userId == null) return 0;
    final List<dynamic> rows = await _supabase
        .from('visit_results')
        .select('id')
        .eq('profile_id', userId)
        .eq('project_id', projectId);
    return rows.length;
  }

  /// 刪除專案；底下的拜訪結果會由資料庫一起刪除（P6）。日常拜訪不能刪
  Future<void> deleteProject(VisitProject project) async {
    if (project.isDefault) throw Exception('日常拜訪是預設專案，不能刪除');
    final String? userId = _currentUserId;
    if (userId == null) {
      _offlineProjects.removeWhere((item) => item.id == project.id);
      return;
    }
    await _supabase.from('visit_projects').delete().eq('id', project.id).eq('profile_id', userId);
  }

  // 名單同步：加入新勾選的、移除取消勾選的
  Future<void> _replaceMembers(String projectId, Set<String> newIds, {required Set<String> existingIds}) async {
    final List<String> removedIds = existingIds.difference(newIds).toList();
    final List<String> addedIds = newIds.difference(existingIds).toList();
    if (removedIds.isNotEmpty) {
      await _supabase
          .from('visit_project_customers')
          .delete()
          .eq('visit_project_id', projectId)
          .inFilter('customer_id', removedIds);
    }
    if (addedIds.isNotEmpty) {
      final List<Map<String, dynamic>> rows = [];
      for (final String customerId in addedIds) {
        rows.add({'visit_project_id': projectId, 'customer_id': customerId, 'is_visited': false});
      }
      await _supabase.from('visit_project_customers').insert(rows);
    }
  }

  Map<String, dynamic> _draftToRow(VisitProjectDraft draft) {
    final bool isRange = draft.periodType == VisitProject.periodRange;
    final DateTime? startDate = draft.startDate;
    final DateTime? endDate = draft.endDate;
    return {
      'title': draft.title.trim(),
      'purpose': draft.purpose.trim(),
      'period_type': draft.periodType,
      'start_date': isRange && startDate != null ? formatDateForDatabase(startDate) : null,
      'end_date': isRange && endDate != null ? formatDateForDatabase(endDate) : null,
      'target_count': draft.targetCount,
    };
  }

  VisitProject _offlineProjectFromDraft(String id, VisitProjectDraft draft, {required bool isDefault}) {
    final bool isRange = draft.periodType == VisitProject.periodRange;
    return VisitProject(
      id: id,
      title: isDefault ? VisitProject.defaultTitle : draft.title.trim(),
      purpose: draft.purpose.trim(),
      periodType: draft.periodType,
      startDate: isRange ? draft.startDate : null,
      endDate: isRange ? draft.endDate : null,
      targetCount: draft.targetCount,
      isDefault: isDefault,
      members: isDefault ? const {} : Map<String, String>.from(draft.members),
      createdAt: DateTime.now(),
    );
  }

  /// 資料庫日期格式 2026-10-15
  static String formatDateForDatabase(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// 測試用：清空離線暫存
  void resetOfflineForTest() {
    _offlineProjects.clear();
    _offlineSequence = 0;
  }
}
