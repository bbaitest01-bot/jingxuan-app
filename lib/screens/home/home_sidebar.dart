import 'dart:convert';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_role.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import 'home_menu.dart';

/// 首頁左側的側邊欄：上方是登入者小卡，中間依角色顯示選單（工作頁面與管理類之間有一條細分隔線），下方是收合與登出按鈕。
/// 電腦版直接放在畫面左邊；手機版放在抽屜（Drawer）裡。
/// 側邊欄本身不保存狀態，所有資料都由 HomeScreen 傳進來，點擊後再通知 HomeScreen。
class HomeSidebar extends StatelessWidget {
  final String activeMenu;
  final bool isCollapsed;
  final bool isWideScreen;
  final String userName;
  final String userEmail;
  final String userAvatarUrl;
  final UserRole userRole;
  final UserRole activeViewRole;

  /// 點選某個選單（或上方小卡）時呼叫，參數是選單名稱
  final ValueChanged<String> onMenuSelected;

  /// 開發者在模擬其他角色時，按「切回工程師」呼叫
  final VoidCallback onReturnToDevView;

  /// 電腦版按收合箭頭時呼叫
  final VoidCallback onToggleCollapse;

  /// 滑鼠移進、移出側邊欄時呼叫（給「懸停自動展開」用）
  final VoidCallback onPointerEnter;
  final VoidCallback onPointerExit;

  final VoidCallback onSignOut;

  const HomeSidebar({
    super.key,
    required this.activeMenu,
    required this.isCollapsed,
    required this.isWideScreen,
    required this.userName,
    required this.userEmail,
    required this.userAvatarUrl,
    required this.userRole,
    required this.activeViewRole,
    required this.onMenuSelected,
    required this.onReturnToDevView,
    required this.onToggleCollapse,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color borderColor = colors.line;

    return MouseRegion(
      onEnter: (_) => onPointerEnter(),
      onExit: (_) => onPointerExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        // 右邊一條細線和內容區分開，不用陰影
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(right: BorderSide(color: borderColor, width: 1)),
        ),
        width: isCollapsed ? 80 : 260,
        child: Column(
          children: [
            _SidebarProfileCard(
              isCollapsed: isCollapsed,
              borderColor: borderColor,
              userName: userName,
              userEmail: userEmail,
              userAvatarUrl: userAvatarUrl,
              userRole: userRole,
              activeViewRole: activeViewRole,
              onTap: () => _selectMenu(context, '個人帳號'),
              onReturnToDevView: onReturnToDevView,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _buildMenuItems(context),
              ),
            ),
            if (isWideScreen) _buildCollapseButton(colors),
            _buildSignOutArea(context, borderColor),
          ],
        ),
      ),
    );
  }

  // 點選選單後，手機版要順便關掉抽屜
  void _selectMenu(BuildContext context, String menu) {
    onMenuSelected(menu);
    if (MediaQuery.of(context).size.width < 768) {
      Navigator.of(context).pop();
    }
  }

  // 依「目前檢視的角色」決定要顯示哪一套選單（主管／開發者／業務員）。
  // 順序不變；工作用的頁面和管理類（垃圾桶、個人帳號、系統設定）之間加一條細分隔線
  List<Widget> _buildMenuItems(BuildContext context) {
    if (activeViewRole == UserRole.admin) {
      return [
        _buildMenuItem(context, Icons.admin_panel_settings_outlined, '👑 團隊戰情室'),
        _buildMenuItem(context, Icons.people_outline, '客戶管理'),
        _buildMenuItem(context, Icons.assignment_outlined, '專案拜訪'),
        _buildMenuItem(context, Icons.hub_outlined, '人脈拓撲'),
        _buildMenuItem(context, Icons.bar_chart_outlined, '數據戰情'),
        _buildMenuItem(context, Icons.newspaper_outlined, '新聞頭條'),
        _buildGroupDivider(context),
        _buildMenuItem(context, Icons.account_circle_outlined, '個人帳號'),
        _buildMenuItem(context, Icons.settings_outlined, '系統設定'),
      ];
    }
    if (activeViewRole == UserRole.dev) {
      return [
        _buildMenuItem(context, Icons.developer_board_outlined, '🛠️ 實體服務診斷'),
        _buildGroupDivider(context),
        _buildMenuItem(context, Icons.account_circle_outlined, '個人帳號'),
        _buildMenuItem(context, Icons.settings_outlined, '系統設定'),
      ];
    }
    return [
      _buildMenuItem(context, Icons.calendar_today_outlined, '今日行程'),
      _buildMenuItem(context, Icons.people_outline, '客戶管理'),
      _buildMenuItem(context, Icons.assignment_outlined, '專案拜訪'),
      _buildMenuItem(context, Icons.record_voice_over_outlined, '拜訪紀錄'),
      _buildMenuItem(context, Icons.hub_outlined, '人脈拓撲'),
      _buildMenuItem(context, Icons.bar_chart_outlined, '數據戰情'),
      _buildMenuItem(context, Icons.newspaper_outlined, '新聞頭條'),
      _buildGroupDivider(context),
      _buildMenuItem(context, Icons.delete_outline, '垃圾桶'),
      _buildMenuItem(context, Icons.account_circle_outlined, '個人帳號'),
      _buildMenuItem(context, Icons.settings_outlined, '系統設定'),
    ];
  }

  // 工作頁面與管理類之間的細分隔線；收合時縮短，避免頂到邊
  Widget _buildGroupDivider(BuildContext context) {
    double sideSpace = 12;
    if (isCollapsed) {
      sideSpace = 16;
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: sideSpace),
      child: Divider(height: 1, thickness: 1, color: context.appColors.line),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String menu) {
    final AppColors colors = context.appColors;
    final bool isActive = activeMenu == menu;

    // 目前所在的選單：淺主題色底＋主題色字；其他選單用次要文字色
    Color itemColor = colors.ink2;
    Color itemBackground = Colors.transparent;
    if (isActive) {
      itemColor = colors.acc;
      itemBackground = colors.accSoft;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => _selectMenu(context, menu),
        borderRadius: BorderRadius.circular(AppRadius.control),
        hoverColor: colors.surface2,
        child: Container(
          decoration: BoxDecoration(
            color: itemBackground,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: itemColor, size: 20),
              if (!isCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    localizedMenuTitle(context, menu),
                    style: TextStyle(
                      color: itemColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(AppColors colors) {
    return IconButton(
      onPressed: onToggleCollapse,
      icon: Icon(
        isCollapsed ? Icons.chevron_right : Icons.chevron_left,
        color: colors.ink3,
      ),
    );
  }

  // 最下方的登出按鈕：收合時只顯示圖示，展開時顯示圖示＋文字
  Widget _buildSignOutArea(BuildContext context, Color borderColor) {
    // 登出用主題裡的危險色（明亮、深色各自調過，不跟主題色變）
    final Color dangerColor = Theme.of(context).colorScheme.error;
    Widget signOutButton;
    if (isCollapsed) {
      signOutButton = IconButton(
        icon: Icon(Icons.logout, color: dangerColor),
        onPressed: onSignOut,
      );
    } else {
      signOutButton = Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(Icons.logout, color: dangerColor),
          title: Text(context.l10n('logout_system'), style: TextStyle(color: dangerColor)),
          onTap: onSignOut,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: signOutButton,
    );
  }
}

/// 側邊欄最上方的登入者小卡：大頭貼、名稱、信箱；點一下會到「個人帳號」頁。
/// 開發者正在模擬其他角色時，會多一個「切回工程師」按鈕。
class _SidebarProfileCard extends StatelessWidget {
  final bool isCollapsed;
  final Color borderColor;
  final String userName;
  final String userEmail;
  final String userAvatarUrl;
  final UserRole userRole;
  final UserRole activeViewRole;
  final VoidCallback onTap;
  final VoidCallback onReturnToDevView;

  const _SidebarProfileCard({
    required this.isCollapsed,
    required this.borderColor,
    required this.userName,
    required this.userEmail,
    required this.userAvatarUrl,
    required this.userRole,
    required this.activeViewRole,
    required this.onTap,
    required this.onReturnToDevView,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Widget content;
    if (isCollapsed) {
      content = Center(child: _buildAvatar(colors));
    } else {
      content = Row(
        children: [
          _buildAvatar(colors),
          const SizedBox(width: 12),
          Expanded(child: _buildNameAndEmail(context)),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: content,
      ),
    );
  }

  // 圓形大頭貼；沒有照片時顯示名字的第一個字
  Widget _buildAvatar(AppColors colors) {
    Widget? initialText;
    if (userAvatarUrl.isEmpty) {
      String initial = '?';
      if (userName.isNotEmpty) {
        initial = userName.substring(0, 1);
      }
      initialText = Text(
        initial,
        style: TextStyle(color: colors.onAcc, fontWeight: FontWeight.bold),
      );
    }

    return CircleAvatar(
      backgroundColor: colors.acc,
      radius: 20,
      backgroundImage: _avatarImageProvider(userAvatarUrl),
      child: initialText,
    );
  }

  Widget _buildNameAndEmail(BuildContext context) {
    final AppColors colors = context.appColors;

    // 離線模式時，信箱的位置改顯示提醒色的「離線模式」
    String emailText = userEmail;
    Color emailColor = colors.ink3;
    if (isOfflineMode) {
      emailText = '離線模式';
      emailColor = colors.warn;
    }

    // 只有開發者帳號、而且正在模擬其他角色時，才顯示「切回工程師」
    final bool isSimulatingOtherRole = userRole == UserRole.dev && activeViewRole != UserRole.dev;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userName,
          style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          emailText,
          style: TextStyle(color: emailColor, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        if (isSimulatingOtherRole) ...[
          const SizedBox(height: 6),
          _buildReturnToDevButton(context),
        ],
      ],
    );
  }

  Widget _buildReturnToDevButton(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color devColor = colors.acc;
    return InkWell(
      onTap: () {
        onReturnToDevView();
        CustomToast.show(context, '已退出模擬，返回核心開發者控制台', ToastType.success);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.accSoft,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: devColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.developer_board_rounded, size: 12, color: devColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '🛠️ ${activeViewRole.shortLabel}模式 (切回工程師)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: devColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 大頭貼網址可能是一般網址，也可能是 Base64 圖片字串（data:image/...），兩種都要能顯示
ImageProvider? _avatarImageProvider(String avatarUrl) {
  if (avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
    try {
      final String base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}
