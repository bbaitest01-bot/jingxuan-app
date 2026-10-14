import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_event.dart';
import 'google_calendar_sync_service.dart';
import '../main.dart';

/// 全域行程業務邏輯與資料存取服務 (Singleton)
class ScheduleService {
  static final ScheduleService instance = ScheduleService._internal();
  ScheduleService._internal();

  final _uuid = const Uuid();

  // 本地快取
  List<ScheduleEvent> _cachedEvents = [];
  List<ScheduleEvent> get cachedEvents => List.unmodifiable(_cachedEvents);

  // 變更通知
  final ValueNotifier<int> eventsRevision = ValueNotifier<int>(0);

  void _notifyChange() {
    eventsRevision.value++;
  }

  // 今日行程的檢視模式（日／月／議程）存在瀏覽器本機；2026-10-14 從 home_screen.dart 搬來
  static const String _viewModePrefKey = 'calendar_view_mode';

  /// 讀回上次選的檢視模式；沒有或讀取失敗回傳 null
  Future<String?> loadSavedViewMode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_viewModePrefKey);
    } catch (e) {
      return null;
    }
  }

  /// 記住目前的檢視模式
  Future<void> saveViewMode(String mode) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewModePrefKey, mode);
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 記住檢視模式失敗: $e');
    }
  }

  User? get _currentUser {
    if (isOfflineMode) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// 依起訖時間查詢行程列表
  Future<List<ScheduleEvent>> fetchEvents({
    DateTime? start,
    DateTime? end,
    bool silent = false,
  }) async {
    final user = _currentUser;

    if (isOfflineMode || user == null) {
      // 離線預覽模式：從 OfflineDataStore 讀取
      // 已放進垃圾桶的不顯示
      final List<Map<String, dynamic>> activeJsonList = OfflineDataStore.scheduleEvents
          .where((json) => json['deleted_at'] == null)
          .toList();
      var localList = activeJsonList.map((json) => ScheduleEvent.fromJson(json)).toList();

      if (start != null && end != null) {
        localList = localList.where((e) {
          return e.startAt.isBefore(end) && e.endAt.isAfter(start);
        }).toList();
      }

      localList.sort((a, b) => a.startAt.compareTo(b.startAt));
      _cachedEvents = localList;
      _notifyChange();
      return localList;
    }

    try {
      var query = Supabase.instance.client
          .from('schedule_events')
          .select()
          .eq('profile_id', user.id)
          .isFilter('deleted_at', null); // 已放進垃圾桶的不顯示

      if (start != null) {
        query = query.gte('end_at', start.toUtc().toIso8601String());
      }
      if (end != null) {
        query = query.lte('start_at', end.toUtc().toIso8601String());
      }

      final data = await query.order('start_at', ascending: true);
      final list = (data as List)
          .map((json) => ScheduleEvent.fromJson(json as Map<String, dynamic>))
          .toList();

      _cachedEvents = list;
      if (GoogleCalendarSyncService.instance.isSyncEnabled) {
        try {
          final aligned = await GoogleCalendarSyncService.instance.pullAndAlignEvents(list);
          _cachedEvents = aligned;
        } catch (_) {}
      }
      // 同步一份至 OfflineDataStore 做本地快取備份
      OfflineDataStore.scheduleEvents = _cachedEvents.map((e) => e.toJson()).toList();
      _notifyChange();
      return _cachedEvents;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 載入行程失敗，降級使用本地快取: $e');
      if (OfflineDataStore.scheduleEvents.isNotEmpty) {
        final fallbackList = OfflineDataStore.scheduleEvents
            .map((json) => ScheduleEvent.fromJson(json))
            .toList();
        _cachedEvents = fallbackList;
        return fallbackList;
      }
      return [];
    }
  }

  /// 首頁「今日行程」用：依目前的視圖，讀取登入者在對應日期範圍內的行程。
  /// 和 fetchEvents 不同：不做 Google 日曆對齊、不寫入本地快取；讀取失敗會把錯誤往外丟，由畫面決定怎麼處理。
  /// 回傳 null 代表目前沒有登入者，畫面應保留原本的資料。
  Future<List<ScheduleEvent>?> fetchOwnEventsForView({
    required DateTime selectedDate,
    required String viewMode,
  }) async {
    final DateTime rangeStart;
    final DateTime rangeEnd;
    if (viewMode == 'month_grid' || viewMode == 'agenda') {
      // 月網格與議程清單：從當月 1 號往前 14 天，讀到下個月的最後一天
      rangeStart = DateTime(selectedDate.year, selectedDate.month, 1, 0, 0, 0).subtract(const Duration(days: 14));
      rangeEnd = DateTime(selectedDate.year, selectedDate.month + 2, 0, 23, 59, 59);
    } else {
      // 日時間軸：只讀選定那一天
      rangeStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      rangeEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
    }

    User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // 等待登入狀態初始化完成（解決首頁剛開啟時讀取為空的問題）
      await Future.delayed(const Duration(milliseconds: 500));
      user = Supabase.instance.client.auth.currentUser;
    }
    if (user == null) return null;

    final List<dynamic> rows = await Supabase.instance.client
        .from('schedule_events')
        .select()
        .eq('profile_id', user.id)
        .isFilter('deleted_at', null) // 已放進垃圾桶的不顯示
        .lte('start_at', rangeEnd.toUtc().toIso8601String())
        .gte('end_at', rangeStart.toUtc().toIso8601String())
        .order('start_at');

    final List<ScheduleEvent> events = [];
    for (final dynamic row in rows) {
      events.add(ScheduleEvent.fromJson(row as Map<String, dynamic>));
    }
    return events;
  }

  /// 新增行程
  Future<ScheduleEvent> createEvent(ScheduleEvent event) async {
    final user = _currentUser;
    final profileId = user?.id ?? 'offline-user';
    final generatedId = event.id.isNotEmpty ? event.id : _uuid.v4();

    final newEvent = event.copyWith(
      id: generatedId,
      profileId: profileId,
      syncStatus: event.syncStatus.isEmpty ? 'local_only' : event.syncStatus,
    );

    if (isOfflineMode || user == null) {
      final json = newEvent.toJson();
      OfflineDataStore.scheduleEvents.insert(0, json);
      _cachedEvents.insert(0, newEvent);
      _notifyChange();
      _syncToGoogleCalendar(newEvent);
      return newEvent;
    }

    final payload = newEvent.toJson();
    try {
      final res = await Supabase.instance.client
          .from('schedule_events')
          .insert(payload)
          .select()
          .single();

      final created = ScheduleEvent.fromJson(res);
      _cachedEvents.removeWhere((e) => e.id == created.id);
      _cachedEvents.add(created);
      _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
      
      OfflineDataStore.scheduleEvents = _cachedEvents.map((e) => e.toJson()).toList();
      _notifyChange();
      _syncToGoogleCalendar(created);
      return created;
    } catch (dbErr) {
      final errStr = dbErr.toString();
      // 相容性處理：若資料庫缺少經緯度等新欄位
      if (errStr.contains('latitude') || errStr.contains('PGRST204')) {
        payload.remove('latitude');
        payload.remove('longitude');
        final res = await Supabase.instance.client
            .from('schedule_events')
            .insert(payload)
            .select()
            .single();
        final created = ScheduleEvent.fromJson(res);
        _cachedEvents.add(created);
        _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
        _notifyChange();
        _syncToGoogleCalendar(created);
        return created;
      }
      rethrow;
    }
  }

  /// 更新行程
  Future<ScheduleEvent> updateEvent(ScheduleEvent event) async {
    final user = _currentUser;

    if (isOfflineMode || user == null) {
      final idx = OfflineDataStore.scheduleEvents.indexWhere((e) => e['id'] == event.id);
      if (idx != -1) {
        OfflineDataStore.scheduleEvents[idx] = event.toJson();
      }
      final cIdx = _cachedEvents.indexWhere((e) => e.id == event.id);
      if (cIdx != -1) {
        _cachedEvents[cIdx] = event;
      }
      _notifyChange();
      _syncToGoogleCalendar(event);
      return event;
    }

    final payload = event.toJson();
    try {
      final res = await Supabase.instance.client
          .from('schedule_events')
          .update(payload)
          .eq('id', event.id)
          .select()
          .single();

      final updated = ScheduleEvent.fromJson(res);
      final idx = _cachedEvents.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _cachedEvents[idx] = updated;
      } else {
        _cachedEvents.add(updated);
      }
      _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

      OfflineDataStore.scheduleEvents = _cachedEvents.map((e) => e.toJson()).toList();
      _notifyChange();
      _syncToGoogleCalendar(updated);
      return updated;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 更新行程失敗: $e');
      rethrow;
    }
  }

  /// 刪除行程：移到垃圾桶（填入 deleted_at），30 天內可以還原（3-F）。
  /// 有同步到 Google 日曆的，先刪掉 Google 上的那筆並清掉對應編號，還原時再重新推送。
  Future<bool> deleteEvent(String id) async {
    final User? user = _currentUser;
    final DateTime deletedAt = DateTime.now();

    final ScheduleEvent target = _cachedEvents.firstWhere(
      (event) => event.id == id,
      orElse: () => ScheduleEvent(id: id, profileId: '', title: '', startAt: DateTime.now(), endAt: DateTime.now()),
    );
    if (GoogleCalendarSyncService.instance.isSyncEnabled && target.isGoogleSynced) {
      GoogleCalendarSyncService.instance.deleteRemoteEvent(target.googleCalendarId, target.googleEventId);
    }

    final Map<String, dynamic> trashFields = {
      'deleted_at': deletedAt.toUtc().toIso8601String(),
      'google_event_id': null,
      'google_calendar_id': null,
      'sync_status': 'local_only',
    };

    if (isOfflineMode || user == null) {
      final int offlineIndex = OfflineDataStore.scheduleEvents.indexWhere((json) => json['id'] == id);
      if (offlineIndex != -1) {
        OfflineDataStore.scheduleEvents[offlineIndex] = {
          ...OfflineDataStore.scheduleEvents[offlineIndex],
          ...trashFields,
        };
      }
      _cachedEvents.removeWhere((event) => event.id == id);
      _notifyChange();
      return true;
    }

    try {
      await Supabase.instance.client
          .from('schedule_events')
          .update(trashFields)
          .eq('id', id);

      _cachedEvents.removeWhere((event) => event.id == id);
      OfflineDataStore.scheduleEvents.removeWhere((json) => json['id'] == id);
      _notifyChange();
      return true;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 行程移到垃圾桶失敗: $e');
      rethrow;
    }
  }

  /// 垃圾桶用：讀取自己放進垃圾桶的行程（最近刪除的排前面）
  Future<List<ScheduleEvent>> fetchDeletedEvents() async {
    final User? user = _currentUser;
    if (isOfflineMode || user == null) {
      final List<ScheduleEvent> deletedEvents = [];
      for (final Map<String, dynamic> json in OfflineDataStore.scheduleEvents) {
        if (json['deleted_at'] != null) deletedEvents.add(ScheduleEvent.fromJson(json));
      }
      deletedEvents.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      return deletedEvents;
    }

    // 主管／開發者的權限看得到別人的行程，所以一定要篩選自己的
    final List<dynamic> rows = await Supabase.instance.client
        .from('schedule_events')
        .select()
        .eq('profile_id', user.id)
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);

    final List<ScheduleEvent> deletedEvents = [];
    for (final dynamic row in rows) {
      deletedEvents.add(ScheduleEvent.fromJson(row as Map<String, dynamic>));
    }
    return deletedEvents;
  }

  /// 從垃圾桶還原行程；有開 Google 日曆同步就重新推送一次
  Future<void> restoreEvent(String id) async {
    final User? user = _currentUser;

    if (isOfflineMode || user == null) {
      final int offlineIndex = OfflineDataStore.scheduleEvents.indexWhere((json) => json['id'] == id);
      if (offlineIndex != -1) {
        final Map<String, dynamic> restoredJson = Map<String, dynamic>.from(OfflineDataStore.scheduleEvents[offlineIndex]);
        restoredJson.remove('deleted_at');
        OfflineDataStore.scheduleEvents[offlineIndex] = restoredJson;
        _cachedEvents.add(ScheduleEvent.fromJson(restoredJson));
      }
      _notifyChange();
      return;
    }

    final Map<String, dynamic> row = await Supabase.instance.client
        .from('schedule_events')
        .update({'deleted_at': null})
        .eq('id', id)
        .select()
        .single();

    final ScheduleEvent restored = ScheduleEvent.fromJson(row);
    _cachedEvents.removeWhere((event) => event.id == restored.id);
    _cachedEvents.add(restored);
    _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    _notifyChange();
    _syncToGoogleCalendar(restored);
  }

  /// 從垃圾桶永久刪除行程（救不回來）
  Future<void> deleteEventForever(String id) async {
    final User? user = _currentUser;

    if (isOfflineMode || user == null) {
      OfflineDataStore.scheduleEvents.removeWhere((json) => json['id'] == id);
      return;
    }

    await Supabase.instance.client
        .from('schedule_events')
        .delete()
        .eq('id', id);
  }

  Future<void> _syncToGoogleCalendar(ScheduleEvent event) async {
    if (!GoogleCalendarSyncService.instance.isSyncEnabled) return;
    try {
      final synced = await GoogleCalendarSyncService.instance.pushLocalToRemote(event);
      if (synced.googleEventId != null && synced.googleEventId != event.googleEventId) {
        final idx = _cachedEvents.indexWhere((e) => e.id == synced.id);
        if (idx != -1) {
          _cachedEvents[idx] = synced;
          _notifyChange();
        }
        if (!isOfflineMode && _currentUser != null) {
          await Supabase.instance.client
              .from('schedule_events')
              .update({
                'google_event_id': synced.googleEventId,
                'google_calendar_id': synced.googleCalendarId,
                'sync_status': synced.syncStatus,
                'last_synced_at': synced.lastSyncedAt?.toUtc().toIso8601String(),
              })
              .eq('id', synced.id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 異步 Google 日曆同步處置警告: $e');
    }
  }

  /// 一鍵切換完成狀態
  Future<bool> toggleComplete(String id, bool isCompleted) async {
    final user = _currentUser;

    final targetIdx = _cachedEvents.indexWhere((e) => e.id == id);
    if (targetIdx != -1) {
      _cachedEvents[targetIdx] = _cachedEvents[targetIdx].copyWith(isCompleted: isCompleted);
      _notifyChange();
    }

    if (isOfflineMode || user == null) {
      final offIdx = OfflineDataStore.scheduleEvents.indexWhere((e) => e['id'] == id);
      if (offIdx != -1) {
        OfflineDataStore.scheduleEvents[offIdx]['is_completed'] = isCompleted;
      }
      return true;
    }

    try {
      await Supabase.instance.client
          .from('schedule_events')
          .update({'is_completed': isCompleted})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 更新完成狀態失敗: $e');
      // 回滾
      if (targetIdx != -1) {
        _cachedEvents[targetIdx] = _cachedEvents[targetIdx].copyWith(isCompleted: !isCompleted);
        _notifyChange();
      }
      return false;
    }
  }
}
