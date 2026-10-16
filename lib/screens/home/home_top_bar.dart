import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import '../../widgets/notification_bell_button.dart';
import 'home_menu.dart';

/// 電腦版右側內容區最上方的頂欄：頁面標題、離線提示、通知小鈴鐺。
class HomeWebHeader extends StatelessWidget {
  final String activeMenu;

  const HomeWebHeader({super.key, required this.activeMenu});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizedMenuTitle(context, activeMenu),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Row(
            children: [
              if (isOfflineMode)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.amber.shade700, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_bolt_outlined, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n('offline_preview_mode'),
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              // 通知鈴鐺（4-E3a：未讀顯示紅色數字）
              NotificationBellButton(iconColor: textColor),
            ],
          )
        ],
      ),
    );
  }
}

/// 手機版最上方的標題列：頁面標題、離線提示、通知小鈴鐺；
/// 在今日行程頁時多出「重新整理」與「新增行程」兩個按鈕。
class HomeMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String activeMenu;
  final bool isSchedulePage;
  final VoidCallback onRefresh;
  final VoidCallback onAddEvent;

  const HomeMobileAppBar({
    super.key,
    required this.activeMenu,
    required this.isSchedulePage,
    required this.onRefresh,
    required this.onAddEvent,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color primaryColor = AppSettings.instance.primaryColor;

    return AppBar(
      title: Text(
        localizedMenuTitle(context, activeMenu),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      iconTheme: IconThemeData(color: textColor),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      elevation: 0,
      actions: [
        if (isOfflineMode)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade900,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              context.l10n('offline_preview'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        if (isSchedulePage) ...[
          IconButton(
            icon: Icon(Icons.refresh, size: 24, color: textColor),
            tooltip: '重新整理',
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 26),
            color: primaryColor,
            tooltip: context.l10n('event_add_title'),
            onPressed: onAddEvent,
          ),
        ],
        NotificationBellButton(iconColor: textColor),
        const SizedBox(width: 8),
      ],
    );
  }
}
