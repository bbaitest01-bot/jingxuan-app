import 'package:flutter/material.dart';
import '../screens/customers/customer_status_widgets.dart';
import '../theme/app_theme.dart';

/// 客戶側邊欄最上面一列（2026-10-30 組長提出，從 customer_detail_side_sheet.dart 拆出）
///
/// 原本卡片翻面才有的按鈕都放在這裡：人脈關聯、編輯資料、匯出分享、全螢幕瀏覽（圖示）、刪除（紅色垃圾桶，在全螢幕瀏覽旁邊）。
/// 原本名字下面的「讀寫合一沉浸式檔案…」口號拿掉（沒有意義）。
/// 沒傳的動作（例：從別的頁面打開時沒有刪除）就不顯示那個按鈕。
class CustomerSheetHeader extends StatelessWidget {
  final String name;
  final String nickname;
  final String avatarUrl;
  final VoidCallback onShare;
  final VoidCallback onFullScreen;
  final VoidCallback onClose;
  final VoidCallback? onManageRelationships;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerSheetHeader({
    super.key,
    required this.name,
    required this.nickname,
    required this.onShare,
    this.avatarUrl = '',
    required this.onFullScreen,
    required this.onClose,
    this.onManageRelationships,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final VoidCallback? manageRelationships = onManageRelationships;
    final VoidCallback? edit = onEdit;
    final VoidCallback? delete = onDelete;
    String nameInitial = '客';
    if (name.isNotEmpty) nameInitial = name.substring(0, 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          // 有大頭貼顯示照片，沒有顯示名字第一個字（2026-10-30 沛沛反映側邊欄沒顯示照片）
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.accSoft,
            backgroundImage: customerAvatarProvider(avatarUrl),
            child: avatarUrl.isEmpty
                ? Text(nameInitial, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.acc))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: _NameText(name: name, nickname: nickname)),
          if (manageRelationships != null)
            _HeaderIconButton(icon: Icons.hub_outlined, tooltip: '人脈關聯', onPressed: manageRelationships),
          if (edit != null) _HeaderIconButton(icon: Icons.edit_outlined, tooltip: '編輯資料', onPressed: edit),
          _HeaderIconButton(icon: Icons.ios_share_rounded, tooltip: '匯出／分享客戶檔案', onPressed: onShare),
          // 原本的放大圖示，滑鼠移上去顯示「全螢幕瀏覽」（2026-10-30 組長：只改文字）
          _HeaderIconButton(icon: Icons.open_in_full_rounded, tooltip: '全螢幕瀏覽', onPressed: onFullScreen),
          if (delete != null)
            _HeaderIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: '刪除客戶',
              onPressed: delete,
              color: Theme.of(context).colorScheme.error,
            ),
          _HeaderIconButton(icon: Icons.close_rounded, tooltip: '關閉', onPressed: onClose),
        ],
      ),
    );
  }
}

class _NameText extends StatelessWidget {
  final String name;
  final String nickname;

  const _NameText({required this.name, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Flexible(
          child: Text(name, style: AppTextStyles.serif(fontSize: 18, color: colors.ink), overflow: TextOverflow.ellipsis),
        ),
        if (nickname.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('($nickname)', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ],
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color ?? context.appColors.ink2),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
