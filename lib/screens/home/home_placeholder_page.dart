import 'package:flutter/material.dart';
import '../../services/app_settings.dart';

/// 選單名稱對不到任何頁面時顯示的「功能骨架」占位頁。
/// 正常操作不會看到；例如重新整理後讀回一個已經不存在的舊選單名稱時才會出現。
class HomePlaceholderPage extends StatelessWidget {
  final String activeMenu;

  const HomePlaceholderPage({super.key, required this.activeMenu});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconForMenu(),
            size: 64,
            color: primaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '$activeMenu 功能骨架',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目前處於 Phase 1，此畫面為選單骨架頁面。\n後續 Phase 將逐步刻劃並串接資料庫實作。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMenu() {
    if (activeMenu == '客戶管理') return Icons.people_outline;
    if (activeMenu == '人脈拓撲') return Icons.hub_outlined;
    return Icons.bar_chart_outlined;
  }
}
