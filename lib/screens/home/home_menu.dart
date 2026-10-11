import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';

/// 把選單內部名稱（例如「今日行程」）轉成目前語言要顯示的文字。
/// 側邊欄與頂欄標題共用，兩邊才不會顯示不一致。
String localizedMenuTitle(BuildContext context, String menu) {
  if (menu == '👑 團隊戰情室') return '👑 團隊戰情室';
  if (menu == '🛠️ 實體服務診斷') return '🛠️ 實體服務診斷';
  if (menu == '今日行程') return context.l10n('today_schedule');
  if (menu == '客戶管理') return context.l10n('customer_mgmt');
  if (menu == '專案拜訪') return context.l10n('project_visits');
  if (menu == '人脈拓撲') return context.l10n('relationship_topology');
  if (menu == '數據戰情') return context.l10n('data_dashboard');
  if (menu == '個人帳號') return context.l10n('personal_account');
  if (menu == '系統設定') return context.l10n('system_settings');
  if (menu == '垃圾桶') return context.l10n('trash_bin');
  return menu;
}
