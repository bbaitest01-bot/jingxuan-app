import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show isOfflineMode;

/// G8（2026-11-08）：把「行程同步到 Google 日曆」的結果收進鈴鐺。
///
/// 同步要等 Google 回應，等的時候使用者可能已經換頁，設定頁就沒辦法跳提示。
/// 所以同步完成後呼叫資料庫函式 `record_calendar_sync_result` 新增一則通知，
/// 通知會即時推送回來，在任何頁面都會跳出通知卡片、收進鈴鐺（和拜訪紀錄整理完成一樣）。
class CalendarSyncNoticeService {
  static final CalendarSyncNoticeService instance = CalendarSyncNoticeService._internal();
  CalendarSyncNoticeService._internal();

  /// 記錄一次同步結果：[syncedCount] 大於 0＝成功；等於 0＝失敗，原因放 [errorMessage]。
  /// 回傳 true＝通知已建立；false＝沒建立成功（例如離線預覽、資料庫還沒更新），由呼叫的畫面自己提示
  Future<bool> recordResult({required int syncedCount, String? errorMessage}) async {
    if (isOfflineMode) return false;
    try {
      await Supabase.instance.client.rpc(
        'record_calendar_sync_result',
        params: {
          'p_synced_count': syncedCount,
          'p_error_message': errorMessage,
        },
      );
      return true;
    } catch (error) {
      debugPrint('[CalendarSyncNoticeService] 建立同步結果通知失敗：$error');
      return false;
    }
  }
}
