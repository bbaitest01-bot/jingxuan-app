import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/visit_record.dart';

/// 選連結客戶時的一筆選項
class VisitCustomerOption {
  final String id;
  final String name;
  final String nickname;
  final String phone;

  const VisitCustomerOption({required this.id, required this.name, this.nickname = '', this.phone = ''});
}

/// 拜訪紀錄的讀寫（資料表 visit_records）。
/// 權限由資料庫 RLS 保證「只能讀寫自己的」；這裡查詢時也一律加上自己的 profile_id。
/// 離線預覽模式存在記憶體，重新整理就清空。
class VisitRecordService {
  static final VisitRecordService instance = VisitRecordService._internal();
  VisitRecordService._internal();

  static const int maxTitleLength = 100;
  static const int maxContentLength = 20000;
  // 讀紀錄時一起帶出連結客戶的名字
  static const String _selectColumns = '*, customers(name, deleted_at)';

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
    if (userId == null) {
      return _offlineRecords.where((record) => record.deletedAt == null).toList();
    }

    final List<dynamic> rows = await _supabase
        .from('visit_records')
        .select(_selectColumns)
        .eq('profile_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final List<VisitRecord> records = [];
    for (final dynamic row in rows) {
      records.add(VisitRecord.fromJson(row as Map<String, dynamic>));
    }
    return records;
  }

  /// 連結某位客戶的拜訪紀錄（客戶細節頁 C7；只列自己的、未刪除，新到舊）
  Future<List<VisitRecord>> fetchRecordsForCustomer(String customerId) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      return _offlineRecords.where((record) => record.deletedAt == null && record.customerId == customerId).toList();
    }

    final List<dynamic> rows = await _supabase
        .from('visit_records')
        .select(_selectColumns)
        .eq('profile_id', userId)
        .eq('customer_id', customerId)
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
        if (record.id == id && record.deletedAt == null) return record;
      }
      return null;
    }

    // id 不是正確格式時資料庫會報錯，當作找不到
    if (!_looksLikeUuid(id)) return null;
    final Map<String, dynamic>? row = await _supabase
        .from('visit_records')
        .select(_selectColumns)
        .eq('id', id)
        .eq('profile_id', userId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return VisitRecord.fromJson(row);
  }

  /// 新增一篇（手動打字或錄音轉文字）；內容存在「原始轉錄」。
  /// [startOrganizing] 為 true（錄音建立）時，一開始就標成「整理中」，接著呼叫 [requestOrganize]
  Future<VisitRecord> createRecord({required String title, required String rawTranscript, bool startOrganizing = false}) async {
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

    final Map<String, dynamic> newRow = {'title': cleanTitle, 'raw_transcript': cleanContent};
    if (startOrganizing) {
      newRow['status'] = VisitRecord.statusProcessing;
      newRow['processing_started_at'] = DateTime.now().toUtc().toIso8601String();
    }
    final Map<String, dynamic> row = await _supabase
        .from('visit_records')
        .insert(newRow)
        .select(_selectColumns)
        .single();
    return VisitRecord.fromJson(row);
  }

  // ---------------------------------------------------------------------------
  // AI 整理（4-E1）：交給雲端函式 organize-visit-record，它再帶密碼呼叫 n8n。
  // App 只送紀錄編號；n8n 的網址與密碼只在伺服器。整理在伺服器背景進行，結果寫回這篇。
  // ---------------------------------------------------------------------------

  /// 請伺服器開始（或重新）整理這篇。伺服器收到就回覆，整理結果之後寫回資料庫
  Future<void> requestOrganize(String recordId) async {
    if (_currentUserId == null) throw Exception('離線預覽模式無法使用 AI 整理');
    try {
      await _supabase.functions.invoke('organize-visit-record', body: {'recordId': recordId});
    } on FunctionException catch (error) {
      final dynamic details = error.details;
      String reason = '無法開始整理（${error.status}）';
      if (details is Map && details['message'] is String) reason = details['message'] as String;
      await _markOrganizeFailed(recordId, reason);
      throw Exception(reason);
    } catch (error) {
      await _markOrganizeFailed(recordId, '連不上整理服務，請稍後重新整理');
      rethrow;
    }
  }

  /// 錄音建立後在背景開始整理；失敗也不打斷使用者（單篇頁會顯示失敗與「重新整理」）
  Future<void> startOrganizeInBackground(String recordId) async {
    try {
      await requestOrganize(recordId);
    } catch (error) {
      debugPrint('[VisitRecordService] 開始 AI 整理失敗：$error');
    }
  }

  // 呼叫不到雲端函式時，自己把狀態改成失敗，免得一直顯示「整理中」
  Future<void> _markOrganizeFailed(String recordId, String reason) async {
    final String? userId = _currentUserId;
    if (userId == null) return;
    try {
      await _supabase
          .from('visit_records')
          .update({'status': VisitRecord.statusFailed, 'failure_reason': reason})
          .eq('id', recordId)
          .eq('profile_id', userId);
    } catch (error) {
      debugPrint('[VisitRecordService] 寫入整理失敗狀態失敗：$error');
    }
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
        customerName: old.customerName,
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
        .select(_selectColumns)
        .single();
    return VisitRecord.fromJson(row);
  }

  /// 連結或更換客戶；[customer] 傳 null 代表取消連結。
  /// 資料庫權限也會檢查：只能連自己的客戶
  Future<VisitRecord> updateCustomerLink(VisitRecord record, VisitCustomerOption? customer) async {
    final String? customerId = customer?.id;
    final String? userId = _currentUserId;
    if (userId == null) {
      final int index = _offlineRecords.indexWhere((item) => item.id == record.id);
      if (index == -1) throw Exception('找不到這篇紀錄');
      final VisitRecord updated = _offlineRecords[index].withCustomer(customerId: customerId, customerName: customer?.name);
      _offlineRecords[index] = updated;
      return updated;
    }

    final Map<String, dynamic> row = await _supabase
        .from('visit_records')
        .update({'customer_id': customerId})
        .eq('id', record.id)
        .eq('profile_id', userId)
        .select(_selectColumns)
        .single();
    return VisitRecord.fromJson(row);
  }

  /// 可以連結的客戶：只列自己的、不在垃圾桶的（主管看得到團隊客戶，但這裡也只列自己的）
  Future<List<VisitCustomerOption>> fetchMyCustomerOptions() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      final List<VisitCustomerOption> offlineOptions = [];
      for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
        if (customer['deleted_at'] != null) continue;
        offlineOptions.add(_customerOptionFromRow(customer));
      }
      return offlineOptions;
    }

    final List<dynamic> rows = await _supabase
        .from('customers')
        .select('id, name, nickname, phone')
        .eq('profile_id', userId)
        .isFilter('deleted_at', null)
        .order('name');
    final List<VisitCustomerOption> options = [];
    for (final dynamic row in rows) {
      options.add(_customerOptionFromRow(row as Map<String, dynamic>));
    }
    return options;
  }

  VisitCustomerOption _customerOptionFromRow(Map<String, dynamic> row) {
    return VisitCustomerOption(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? '',
      nickname: row['nickname']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
    );
  }

  /// 依名字、暱稱或電話數字篩選客戶選項（空白搜尋顯示全部）
  static List<VisitCustomerOption> filterCustomerOptions(List<VisitCustomerOption> options, String query) {
    final String keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return options;
    // 搜尋文字看起來像電話（只有數字、-、空白、括號、+）才比對電話，避免「王1」比對到一堆電話（同 3-B 客戶搜尋）
    final bool looksLikePhone = RegExp(r'^[0-9\s\-()+]+$').hasMatch(keyword);
    final String keywordDigits = looksLikePhone ? keyword.replaceAll(RegExp(r'[^0-9]'), '') : '';

    final List<VisitCustomerOption> matched = [];
    for (final VisitCustomerOption option in options) {
      final bool nameMatched = option.name.toLowerCase().contains(keyword) || option.nickname.toLowerCase().contains(keyword);
      final String phoneDigits = option.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final bool phoneMatched = keywordDigits.isNotEmpty && phoneDigits.contains(keywordDigits);
      if (nameMatched || phoneMatched) matched.add(option);
    }
    return matched;
  }

  // ---------------------------------------------------------------------------
  // 垃圾桶（4-D）：刪除先填 deleted_at，30 天內可還原，之後由每日排程永久刪除
  // ---------------------------------------------------------------------------

  /// 移到垃圾桶
  Future<void> moveToTrash(String id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _replaceOfflineRecord(id, (record) => record.withDeletedAt(DateTime.now()));
      return;
    }
    await _supabase
        .from('visit_records')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('profile_id', userId);
  }

  /// 垃圾桶裡自己的拜訪紀錄（最近刪除的在前）
  Future<List<VisitRecord>> fetchDeletedRecords() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      final List<VisitRecord> deletedRecords = _offlineRecords.where((record) => record.deletedAt != null).toList();
      deletedRecords.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      return deletedRecords;
    }

    final List<dynamic> rows = await _supabase
        .from('visit_records')
        .select(_selectColumns)
        .eq('profile_id', userId)
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);
    final List<VisitRecord> records = [];
    for (final dynamic row in rows) {
      records.add(VisitRecord.fromJson(row as Map<String, dynamic>));
    }
    return records;
  }

  /// 從垃圾桶還原
  Future<void> restoreRecord(String id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _replaceOfflineRecord(id, (record) => record.withDeletedAt(null));
      return;
    }
    await _supabase
        .from('visit_records')
        .update({'deleted_at': null})
        .eq('id', id)
        .eq('profile_id', userId);
  }

  /// 從垃圾桶永久刪除（救不回來）
  Future<void> deleteRecordForever(String id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _offlineRecords.removeWhere((record) => record.id == id);
      return;
    }
    await _supabase
        .from('visit_records')
        .delete()
        .eq('id', id)
        .eq('profile_id', userId);
  }

  void _replaceOfflineRecord(String id, VisitRecord Function(VisitRecord record) change) {
    final int index = _offlineRecords.indexWhere((record) => record.id == id);
    if (index == -1) throw Exception('找不到這篇紀錄');
    _offlineRecords[index] = change(_offlineRecords[index]);
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
