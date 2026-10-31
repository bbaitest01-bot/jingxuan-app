import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/schedule_event.dart';

/// 帶有 Google OAuth Access Token 的 HTTP Client
class _GoogleOAuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _GoogleOAuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Google 日曆單向推送服務 (Singleton)
/// 規則：經選助手 App 為正本、Google 日曆為副本；僅單向推送到 Google，不拉取 Google 私人行程
class GoogleCalendarSyncService {
  static final GoogleCalendarSyncService instance = GoogleCalendarSyncService._internal();
  GoogleCalendarSyncService._internal();

  /// Google 日曆名稱（改為經選助手）
  static const String _secondaryCalendarName = '經選助手';
  static const String _prefSyncEnabledKey = 'google_calendar_sync_enabled';
  static const String _prefCalendarIdKey = 'google_calendar_secondary_id';
  static const String _prefProviderTokenKey = 'google_oauth_provider_token';

  /// 行程說明欄自動加註警語，防手滑在 Google 端修改
  static const String syncNotice = '【此行程由經選助手建立，請至經選助手 App 修改】';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      calendar.CalendarApi.calendarScope,
      calendar.CalendarApi.calendarEventsScope,
    ],
  );

  bool _isSyncEnabled = false;
  bool get isSyncEnabled => _isSyncEnabled;

  String? _secondaryCalendarId;
  String? get secondaryCalendarId => _secondaryCalendarId;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  // 允許測試時注入 Mock Client
  http.Client? mockHttpClient;

  /// 初始化同步服務設定（優先載入本地快取）
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSyncEnabled = prefs.getBool(_prefSyncEnabledKey) ?? false;
      _secondaryCalendarId = prefs.getString(_prefCalendarIdKey);
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 初始化失敗: $e');
    }
  }

  /// 登入後套用帳號（user_metadata）存的同步設定，換裝置或清除快取時自動恢復
  Future<void> applyCloudSettings() async {
    if (isOfflineMode) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null && user.userMetadata!['calendar_sync'] != null) {
        final Map<String, dynamic> cloudData = Map<String, dynamic>.from(user.userMetadata!['calendar_sync']);
        bool hasChanges = false;
        if (cloudData.containsKey('is_sync_enabled')) {
          final bool cloudEnabled = cloudData['is_sync_enabled'] == true;
          if (_isSyncEnabled != cloudEnabled) {
            _isSyncEnabled = cloudEnabled;
            hasChanges = true;
          }
        }
        if (cloudData.containsKey('secondary_calendar_id')) {
          final String? cloudCalId = cloudData['secondary_calendar_id'] as String?;
          if (_secondaryCalendarId != cloudCalId) {
            _secondaryCalendarId = cloudCalId;
            hasChanges = true;
          }
        }
        if (hasChanges) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_prefSyncEnabledKey, _isSyncEnabled);
          if (_secondaryCalendarId != null) {
            await prefs.setString(_prefCalendarIdKey, _secondaryCalendarId!);
          } else {
            await prefs.remove(_prefCalendarIdKey);
          }
        }
      } else if (user != null && (_isSyncEnabled || _secondaryCalendarId != null)) {
        // 若雲端帳號尚無紀錄，但本機已開啟同步，自動將本機設定同步至帳號
        await _syncToCloud();
      }
    } catch (e) {
      if (e is! AssertionError) {
        debugPrint('⚠️ [GoogleCalendarSyncService] 套用雲端同步設定失敗: $e');
      }
    }
  }

  /// 儲存至本機 SharedPreferences 與 Supabase 帳號（跟隨帳號走）
  Future<void> _saveToLocalAndCloud() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSyncEnabledKey, _isSyncEnabled);
      if (_secondaryCalendarId != null) {
        await prefs.setString(_prefCalendarIdKey, _secondaryCalendarId!);
      } else {
        await prefs.remove(_prefCalendarIdKey);
      }
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 儲存本機設定失敗: $e');
    }

    await _syncToCloud();
  }

  /// 同步至 Supabase 帳號 metadata
  Future<void> _syncToCloud() async {
    if (isOfflineMode) return;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...?user.userMetadata,
              'calendar_sync': {
                'is_sync_enabled': _isSyncEnabled,
                'secondary_calendar_id': _secondaryCalendarId,
                'updated_at': DateTime.now().toIso8601String(),
              },
            },
          ),
        );
      }
    } catch (e) {
      if (e is! AssertionError) {
        debugPrint('⚠️ [GoogleCalendarSyncService] 同步日曆設定至帳號失敗: $e');
      }
    }
  }

  /// 設定是否啟用 Google 日曆同步
  Future<void> setSyncEnabled(bool enabled) async {
    _isSyncEnabled = enabled;
    await _saveToLocalAndCloud();
  }

  /// 組合行程說明文字（自動附上經選助手警語）
  static String buildEventDescription(String? originalDescription) {
    if (originalDescription == null || originalDescription.trim().isEmpty) {
      return syncNotice;
    }
    if (originalDescription.contains('此行程由經選助手建立')) {
      return originalDescription;
    }
    return '$originalDescription\n\n$syncNotice';
  }

  /// 取得授權的 CalendarApi 客戶端
  Future<calendar.CalendarApi?> _getCalendarApi() async {
    if (mockHttpClient != null) {
      return calendar.CalendarApi(mockHttpClient!);
    }

    try {
      // 1. 優先從 Supabase 連線取得 Google Access Token (providerToken)
      try {
        final session = Supabase.instance.client.auth.currentSession;
        final providerToken = session?.providerToken;
        if (providerToken != null && providerToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefProviderTokenKey, providerToken);
          debugPrint('✅ [GoogleCalendarSyncService] 使用 Supabase Google Provider Token 連線');
          return calendar.CalendarApi(_GoogleOAuthClient(providerToken));
        }
      } catch (_) {}

      // 1.5 若 session 的 providerToken 在跳轉後遺失，嘗試從本地快取讀取
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedToken = prefs.getString(_prefProviderTokenKey);
        if (cachedToken != null && cachedToken.isNotEmpty) {
          debugPrint('✅ [GoogleCalendarSyncService] 使用快取 Google Provider Token 連線');
          return calendar.CalendarApi(_GoogleOAuthClient(cachedToken));
        }
      } catch (_) {}

      // 2. 備案：嘗試從 GoogleSignIn 取得（若為原生端或手動登入）
      var currentUser = _googleSignIn.currentUser;
      currentUser ??= await _googleSignIn.signInSilently();

      if (currentUser != null) {
        final authClient = await _googleSignIn.authenticatedClient();
        if (authClient != null) {
          return calendar.CalendarApi(authClient);
        }
      }

      _lastErrorMessage = '尚未取得 Google 憑證（請點擊「重新授權」並允許日曆存取）';
      debugPrint('⚠️ [GoogleCalendarSyncService] $_lastErrorMessage');
      return null;
    } catch (e) {
      _lastErrorMessage = '取得授權失敗: $e';
      debugPrint('⚠️ [GoogleCalendarSyncService] 取得 CalendarApi 失敗: $e');
      return null;
    }
  }

  /// 取得或創建專屬次日曆「經選助手」
  /// 注意：若失敗絕不降級推送到使用者的私人主日曆 (primary)
  Future<String?> getOrCreateSecondaryCalendar(calendar.CalendarApi api) async {
    if (_secondaryCalendarId != null && _secondaryCalendarId!.isNotEmpty) {
      return _secondaryCalendarId;
    }

    try {
      // 1. 搜尋現有日曆列表（相容舊名「保險助手」，避免重複建立）
      final calendarList = await api.calendarList.list();
      if (calendarList.items != null) {
        for (final cal in calendarList.items!) {
          final summary = cal.summary ?? '';
          if (summary == _secondaryCalendarName ||
              summary == '經選助手' ||
              summary == '保險助手' ||
              summary == '保險助手 (Insurance Helper)') {
            _secondaryCalendarId = cal.id;
            if (cal.id != null) {
              await _saveCalendarId(cal.id!);
            }
            return cal.id;
          }
        }
      }

      // 2. 若不存在則建立「經選助手」次日曆
      final newCalendar = calendar.Calendar()
        ..summary = _secondaryCalendarName
        ..description = '經選助手專案自動同步之專屬行程日曆（App 為正本，請至 App 修改）'
        ..timeZone = 'Asia/Taipei';

      final createdCal = await api.calendars.insert(newCalendar);
      _secondaryCalendarId = createdCal.id;
      if (createdCal.id != null) {
        await _saveCalendarId(createdCal.id!);
      }
      return createdCal.id;
    } catch (e) {
      _lastErrorMessage = 'Google 日曆建立/搜尋失敗: $e';
      debugPrint('⚠️ [GoogleCalendarSyncService] 取得/建立「經選助手」次日曆失敗: $e');
      return null;
    }
  }

  Future<void> _saveCalendarId(String calId) async {
    _secondaryCalendarId = calId;
    await _saveToLocalAndCloud();
  }

  /// 推送單筆本地行程至 Google 日曆（單向新增或更新）
  Future<ScheduleEvent> pushLocalToRemote(ScheduleEvent event) async {
    if (!_isSyncEnabled) return event;

    final api = await _getCalendarApi();
    if (api == null) {
      return event.copyWith(syncStatus: 'pending_push');
    }

    try {
      final calendarId = await getOrCreateSecondaryCalendar(api);
      if (calendarId == null) {
        debugPrint('⚠️ [GoogleCalendarSyncService] 無法取得次日曆 ID，取消推送');
        return event.copyWith(syncStatus: 'pending_push');
      }

      final googleEvent = calendar.Event()
        ..summary = event.title
        ..description = buildEventDescription(event.description)
        ..location = event.location
        ..start = calendar.EventDateTime(dateTime: event.startAt.toUtc())
        ..end = calendar.EventDateTime(dateTime: event.endAt.toUtc())
        ..extendedProperties = calendar.EventExtendedProperties(
          private: {
            'jingxuan_event_id': event.id,
            'insurance_helper_id': event.id,
          },
        );

      calendar.Event resultEvent;

      if (event.googleEventId != null && event.googleEventId!.isNotEmpty) {
        // 更新現有 Google 行程
        try {
          resultEvent = await api.events.update(googleEvent, calendarId, event.googleEventId!);
        } catch (_) {
          // 若遠端已被手動刪除，改為重新新增
          resultEvent = await api.events.insert(googleEvent, calendarId);
        }
      } else {
        // 全新新增 Google 行程
        resultEvent = await api.events.insert(googleEvent, calendarId);
      }

      return event.copyWith(
        googleEventId: resultEvent.id,
        googleCalendarId: calendarId,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      _lastErrorMessage = '推送行程失敗: $e';
      debugPrint('⚠️ [GoogleCalendarSyncService] 推送行程至 Google 日曆失敗: $e');
      return event.copyWith(syncStatus: 'pending_push');
    }
  }

  /// 從 Google 日曆刪除行程（當 App 刪除行程時連動刪除 Google 副本）
  Future<bool> deleteRemoteEvent(String? googleCalendarId, String? googleEventId) async {
    if (!_isSyncEnabled || googleEventId == null || googleEventId.isEmpty) {
      return true;
    }

    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final calId = googleCalendarId ?? _secondaryCalendarId;
      if (calId == null) return false;

      await api.events.delete(calId, googleEventId);
      return true;
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 刪除 Google 日曆行程失敗: $e');
      return false;
    }
  }

  /// 一鍵重新同步所有行程（單向推送補回）
  /// 萬一使用者在 Google 日曆誤刪，在 App 點此功能可將未來的行程重新推送
  Future<int> resyncAllEvents(List<ScheduleEvent> events) async {
    _lastErrorMessage = null;
    if (!_isSyncEnabled) {
      _lastErrorMessage = '同步開關未開啟';
      return 0;
    }

    final api = await _getCalendarApi();
    if (api == null) return 0;

    int syncedCount = 0;
    for (final event in events) {
      // 已在 App 被軟刪除的行程不推送
      if (event.deletedAt != null) continue;

      final updated = await pushLocalToRemote(event);
      if (updated.syncStatus == 'synced') {
        syncedCount++;
        // 同步更新資料庫的 google_event_id 與狀態
        if (!isOfflineMode && Supabase.instance.client.auth.currentUser != null) {
          try {
            await Supabase.instance.client
                .from('schedule_events')
                .update({
                  'google_event_id': updated.googleEventId,
                  'google_calendar_id': updated.googleCalendarId,
                  'sync_status': updated.syncStatus,
                  'last_synced_at': updated.lastSyncedAt?.toUtc().toIso8601String(),
                })
                .eq('id', updated.id);
          } catch (_) {}
        }
      }
    }

    debugPrint('✅ [GoogleCalendarSyncService] 重新同步完成，成功推送 $syncedCount 筆行程');
    return syncedCount;
  }

  /// 將 ScheduleEvent 物件轉為 googleapis.Event 物件（單元測試與輔助用）
  calendar.Event toGoogleEvent(ScheduleEvent event) {
    return calendar.Event()
      ..summary = event.title
      ..description = buildEventDescription(event.description)
      ..location = event.location
      ..start = calendar.EventDateTime(dateTime: event.startAt.toUtc())
      ..end = calendar.EventDateTime(dateTime: event.endAt.toUtc())
      ..extendedProperties = calendar.EventExtendedProperties(
        private: {
          'jingxuan_event_id': event.id,
          'insurance_helper_id': event.id,
        },
      );
  }
}
