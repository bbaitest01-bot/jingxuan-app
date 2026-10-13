import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/visit_record.dart';

/// 拜訪紀錄的讀寫（資料表 visit_records）。
/// 權限由資料庫 RLS 保證「只能讀寫自己的」；這裡查詢時也一律加上自己的 profile_id。
/// 離線預覽模式存在記憶體，重新整理就清空。
class VisitRecordService {
  static final VisitRecordService instance = VisitRecordService._internal();
  VisitRecordService._internal();

  static const int maxTitleLength = 100;
  static const int maxContentLength = 20000;

  // 離線預覽模式用的暫存
  final List<VisitRecord> _offlineRecords = [];

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId {
    if (isOfflineMode) return null;
    return _supabase.auth.currentUser?.id;
  }

  /// 自己的拜訪紀錄（未刪除，新到舊）
  Future<List<VisitRecord>> fetchMyRecords() async {
    final String? userId = _currentUserId;
    if (userId == null) return List<VisitRecord>.from(_offlineRecords);

    final List<dynamic> rows = await _supabase
        .from('visit_records')
        .select()
        .eq('profile_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final List<VisitRecord> records = [];
    for (final dynamic row in rows) {
      records.add(VisitRecord.fromJson(row as Map<String, dynamic>));
    }
    return records;
  }

  /// 讀一篇；找不到（不存在、已刪除或不是自己的）回傳 null
  Future<VisitRecord?> fetchRecord(String id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      for (final VisitRecord record in _offlineRecords) {
        if (record.id == id) return record;
      }
      return null;
    }

    // id 不是正確格式時資料庫會報錯，當作找不到
    if (!_looksLikeUuid(id)) return null;
    final Map<String, dynamic>? row = await _supabase
        .from('visit_records')
        .select()
        .eq('id', id)
        .eq('profile_id', userId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return VisitRecord.fromJson(row);
  }

  /// 新增一篇（手動打字或之後的錄音轉文字）；內容存在「原始轉錄」
  Future<VisitRecord> createRecord({required String title, required String rawTranscript}) async {
    final String cleanTitle = _cleanTitle(title);
    final String cleanContent = rawTranscript.trim();
    if (cleanContent.length > maxContentLength) {
      throw Exception('內容超過 $maxContentLength 字，請分成多篇');
    }

    final String? userId = _currentUserId;
    if (userId == null) {
      final DateTime now = DateTime.now();
      final VisitRecord record = VisitRecord(
        id: 'offline-${now.millisecondsSinceEpoch}',
        profileId: 'offline-user',
        title: cleanTitle,
        rawTranscript: cleanContent,
        status: VisitRecord.statusRaw,
        createdAt: now,
        updatedAt: now,
      );
      _offlineRecords.insert(0, record);
      return record;
    }

    final Map<String, dynamic> row = await _supabase
        .from('visit_records')
        .insert({'title': cleanTitle, 'raw_transcript': cleanContent})
        .select()
        .single();
    return VisitRecord.fromJson(row);
  }

  /// 修改標題與整理後內容（原始轉錄不改，一律保留）
  Future<VisitRecord> updateRecord(String id, {required String title, required String organizedContent}) async {
    final String cleanTitle = _cleanTitle(title);
    final String cleanContent = organizedContent.trim();
    if (cleanContent.length > maxContentLength) {
      throw Exception('內容超過 $maxContentLength 字');
    }
    final String? contentToSave = cleanContent.isEmpty ? null : cleanContent;

    final String? userId = _currentUserId;
    if (userId == null) {
      final int index = _offlineRecords.indexWhere((record) => record.id == id);
      if (index == -1) throw Exception('找不到這篇紀錄');
      final VisitRecord old = _offlineRecords[index];
      final VisitRecord updated = VisitRecord(
        id: old.id,
        profileId: old.profileId,
        customerId: old.customerId,
        title: cleanTitle,
        rawTranscript: old.rawTranscript,
        organizedContent: contentToSave,
        status: old.status,
        failureReason: old.failureReason,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _offlineRecords[index] = updated;
      return updated;
    }

    final Map<String, dynamic> row = await _supabase
        .from('visit_records')
        .update({'title': cleanTitle, 'organized_content': contentToSave})
        .eq('id', id)
        .eq('profile_id', userId)
        .select()
        .single();
    return VisitRecord.fromJson(row);
  }

  // 標題空白就用預設標題；太長就截斷
  String _cleanTitle(String title) {
    String cleanTitle = title.trim();
    if (cleanTitle.isEmpty) cleanTitle = VisitRecord.defaultTitle(DateTime.now());
    if (cleanTitle.length > maxTitleLength) cleanTitle = cleanTitle.substring(0, maxTitleLength);
    return cleanTitle;
  }

  bool _looksLikeUuid(String id) {
    return RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id);
  }

  @visibleForTesting
  void clearOfflineRecordsForTest() => _offlineRecords.clear();
}
