import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';
import '../../services/tag_categorizer.dart';
import '../../widgets/animations.dart';
import 'customer_grid_view.dart';
import 'customer_shimmers.dart';
import 'customer_status_widgets.dart';
import '../../theme/app_theme.dart';

/// 條列模式：每位客戶一列
class CustomerListView extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final bool isWideScreen;
  final bool isSelectionMode;
  final Set<String> selectedCustomerIds;
  final CustomerCardActions actions;

  /// false 時每一列直接出現、不播淡入動畫
  final bool animateEntrance;

  const CustomerListView({
    super.key,
    required this.customers,
    required this.isWideScreen,
    required this.isSelectionMode,
    required this.selectedCustomerIds,
    required this.actions,
    this.animateEntrance = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return StaggeredFadeIn(
          index: index,
          animate: animateEntrance,
          child: CustomerListRow(
            customer: customer,
            isWideScreen: isWideScreen,
            isSelectionMode: isSelectionMode,
            selectedCustomerIds: selectedCustomerIds,
            actions: actions,
          ),
        );
      },
    );
  }
}

/// 條列模式的載入中骨架
class CustomerShimmerList extends StatelessWidget {
  const CustomerShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const CustomerListShimmer();
      },
    );
  }
}

/// 條列模式的一列：電腦版分成頭像姓名、聯絡方式、標籤、備註、按鈕五欄；手機版上下排列
class CustomerListRow extends StatelessWidget {
  final Map<String, dynamic> customer;
  final bool isWideScreen;
  final bool isSelectionMode;
  final Set<String> selectedCustomerIds;
  final CustomerCardActions actions;

  const CustomerListRow({
    super.key,
    required this.customer,
    required this.isWideScreen,
    required this.isSelectionMode,
    required this.selectedCustomerIds,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final String name = customer['name'] ?? '';
    final String nickname = customer['nickname'] ?? '';
    final String phone = customer['phone'] ?? '未填寫';
    final String email = customer['email'] ?? '未填寫';
    final List tags = customer['tags'] ?? [];
    final String notes = customer['notes'] ?? '';
    final String avatarUrl = customer['avatar_url'] ?? '';

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = context.appColors.acc;
    final Color cardBg = context.appColors.surface;
    final Color cardBorder = context.appColors.line;
    final Color nameColor = context.appColors.ink;
    final Color infoColor = context.appColors.ink3;
    final Color iconColor = context.appColors.ink3;

    Widget child;

    if (isWideScreen) {
      // Wide layout (Desktop/Tablet)
      child = Row(
        children: [
          // 1. Avatar & Display Name
          SizedBox(
            width: 180,
            child: Row(
              children: [
                if (isSelectionMode) ...[
            Checkbox(
              value: selectedCustomerIds.contains(customer['id'].toString()),
              onChanged: (val) {
                actions.onSelectionChanged(customer['id'].toString(), val == true);
              },
              activeColor: context.appColors.acc,
            ),
            const SizedBox(width: 8),
          ],
          CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  radius: 20,
                  backgroundImage: customerAvatarProvider(avatarUrl),
                  child: avatarUrl.isEmpty
                      ? Text(
                          nameInitial,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomerNameWithStatus(
                        name: displayName,
                        status: customer['client_status'] as String?,
                        style: TextStyle(color: nameColor, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (customer['agent_name'] != null && customer['agent_name'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '👤 業務員: ${customer['agent_name']}',
                          style: TextStyle(
                            color: context.appColors.acc,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. Contact Info (Phone & Email)
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        phone,
                        style: TextStyle(color: infoColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 12, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(color: infoColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Tags Column (Wrap with dynamic flex)
          Expanded(
            flex: 2,
            child: tags.isNotEmpty
                ? Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags.take(4).map((tag) {
                      final style = TagCategorizer.getStyle(tag.toString(), isDark);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag.toString(),
                          style: TextStyle(
                            color: style.textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    '無標籤',
                    style: TextStyle(color: infoColor, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
          ),
          const SizedBox(width: 12),

          // 4. Notes preview
          Expanded(
            flex: 3,
            child: Text(
              notes.isNotEmpty ? notes : '無備註資料',
              style: TextStyle(
                color: notes.isNotEmpty ? infoColor : (context.appColors.ink3),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // 5. Actions row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 20),
                tooltip: context.l10n('customer_card_zoom_tooltip'),
                onPressed: () => actions.onZoom(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: infoColor, size: 18),
                onPressed: () => actions.onEdit(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 18),
                onPressed: () => actions.onDelete(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      );
    } else {
      // Narrow layout (Mobile/Compact)
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                radius: 18,
                backgroundImage: customerAvatarProvider(avatarUrl),
                child: avatarUrl.isEmpty
                    ? Text(
                        nameInitial,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomerNameWithStatus(
                      name: displayName,
                      status: customer['client_status'] as String?,
                      style: TextStyle(color: nameColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(color: infoColor, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 18),
                onPressed: () => actions.onZoom(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: infoColor, size: 16),
                onPressed: () => actions.onEdit(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 16),
                onPressed: () => actions.onDelete(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tags.take(3).map((tag) {
                final style = TagCategorizer.getStyle(tag.toString(), isDark);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag.toString(),
                    style: TextStyle(
                      color: style.textColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: TextStyle(
                color: context.appColors.ink3,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: HoverAnimatedCard(
        child: Card(
          margin: EdgeInsets.zero,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cardBorder, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
