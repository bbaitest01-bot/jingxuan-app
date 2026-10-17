import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_bell_button.dart';
import 'home_menu.dart';

/// 電腦版右側內容區最上方的頂欄：頁面標題（宋體）、離線提示、通知小鈴鐺。
class HomeWebHeader extends StatelessWidget {
  final String activeMenu;

  const HomeWebHeader({super.key, required this.activeMenu});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.line, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 頁面標題用宋體，和登入頁的大標語同一套字
          Text(
            localizedMenuTitle(context, activeMenu),
            style: AppTextStyles.serif(fontSize: 22, color: colors.ink),
          ),
          Row(
            children: [
              if (isOfflineMode) const _OfflinePreviewBadge(),
              // 通知鈴鐺（4-E3a：未讀顯示紅色數字）
              NotificationBellButton(iconColor: colors.ink2),
            ],
          )
        ],
      ),
    );
  }
}

/// 電腦版頂欄右邊的「離線預覽模式」標籤：淡提醒色底、提醒色字
class _OfflinePreviewBadge extends StatelessWidget {
  const _OfflinePreviewBadge();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.warnSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt_outlined, size: 14, color: colors.warn),
          const SizedBox(width: 6),
          Text(
            context.l10n('offline_preview_mode'),
            style: TextStyle(color: colors.warn, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// 手機版最上方的標題列：頁面標題（宋體）、離線提示、通知小鈴鐺；
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
    final AppColors colors = context.appColors;

    return AppBar(
      title: Text(
        localizedMenuTitle(context, activeMenu),
        style: AppTextStyles.serif(fontSize: 20, color: colors.ink),
      ),
      iconTheme: IconThemeData(color: colors.ink2),
      backgroundColor: colors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      // 底下一條細線和內容分開，不用陰影
      shape: Border(bottom: BorderSide(color: colors.line, width: 1)),
      actions: [
        if (isOfflineMode)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.warnSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              context.l10n('offline_preview'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.warn),
            ),
          ),
        if (isSchedulePage) ...[
          IconButton(
            icon: Icon(Icons.refresh, size: 24, color: colors.ink2),
            tooltip: '重新整理',
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 26),
            color: colors.acc,
            tooltip: context.l10n('event_add_title'),
            onPressed: onAddEvent,
          ),
        ],
        NotificationBellButton(iconColor: colors.ink2),
        const SizedBox(width: 8),
      ],
    );
  }
}
