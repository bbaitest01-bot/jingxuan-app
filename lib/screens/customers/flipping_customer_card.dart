import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';
import '../../services/tag_categorizer.dart';
import 'customer_status_widgets.dart';
import '../../theme/app_theme.dart';

// ==========================================
// 3D Flipping Customer Card Widget
// ==========================================

class FlippingCustomerCard extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onZoom;
  final VoidCallback? onManageRelationships;

  const FlippingCustomerCard({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onZoom,
    this.onManageRelationships,
  });


  @override
  State<FlippingCustomerCard> createState() => _FlippingCustomerCardState();
}

class _FlippingCustomerCardState extends State<FlippingCustomerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }




  @override
  Widget build(BuildContext context) {
    final String name = widget.customer['name'] ?? '';
    final String nickname = widget.customer['nickname'] ?? '';
    final String phone = widget.customer['phone'] ?? '未填寫';
    final String email = widget.customer['email'] ?? '未填寫';
    final List tags = widget.customer['tags'] ?? [];
    final String notes = widget.customer['notes'] ?? '';
    final String avatarUrl = widget.customer['avatar_url'] ?? '';

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double transformVal = _controller.value * 3.1415926535;
        final bool showFrontSide = transformVal < (3.1415926535 / 2);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _flip,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(transformVal),
            alignment: Alignment.center,
            child: showFrontSide
                ? _buildFront(name, nickname, displayName, phone, email, tags, avatarUrl, nameInitial)
                : Transform(
                    // Counter rotate back side
                    transform: Matrix4.identity()..rotateY(3.1415926535),
                    alignment: Alignment.center,
                    child: _buildBack(name, notes),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFront(
    String name,
    String nickname,
    String displayName,
    String phone,
    String email,
    List tags,
    String avatarUrl,
    String nameInitial,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = context.appColors.acc;
    final Color cardBg = context.appColors.surface;
    final Color cardBorder = context.appColors.line;
    final Color nameColor = context.appColors.ink;
    final Color infoColor = context.appColors.ink3;
    final Color iconColor = context.appColors.ink3;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: InkWell(
        onTap: _flip,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section (Avatar & Info & Flip icon)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Photo support
                  CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.12),
                    radius: 24,
                    backgroundImage: customerAvatarProvider(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(
                            nameInitial,
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name & Info Columns
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomerNameWithStatus(
                          name: displayName,
                          status: widget.customer['client_status'] as String?,
                          style: TextStyle(color: nameColor, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 12, color: iconColor),
                            const SizedBox(width: 4),
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
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(color: infoColor, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.customer['agent_name'] != null && widget.customer['agent_name'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 12, color: context.appColors.acc),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '👤 業務員: ${widget.customer['agent_name']}',
                                  style: TextStyle(color: context.appColors.acc, fontSize: 10, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action icons on the right (Zoom & Flip)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.fullscreen_rounded, color: iconColor, size: 20),
                        tooltip: context.l10n('customer_card_zoom_tooltip'),
                        onPressed: widget.onZoom,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.flip_camera_android_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Tags Row
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.take(3).map((tag) {
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(String name, String notes) {
    final Color primaryColor = context.appColors.acc;
    final Color cardBg = context.appColors.surface;
    final Color subTextColor = context.appColors.ink3;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1.5),
      ),
      child: InkWell(
        onTap: _flip,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${context.l10n('customer_card_notes_title')} ($name)',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 16),
                        tooltip: context.l10n('customer_card_zoom_tooltip'),
                        onPressed: widget.onZoom,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: subTextColor, size: 16),
                        onPressed: widget.onEdit,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 16),
                        onPressed: widget.onDelete,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.flip_camera_android_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: context.appColors.line, height: 12),
              if (widget.onManageRelationships != null) ...[
                InkWell(
                  onTap: widget.onManageRelationships,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hub_rounded, size: 12, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              '👥 人脈與轉介紹關聯',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ],
                        ),
                        Icon(Icons.edit_note_rounded, size: 12, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    notes.isNotEmpty ? notes : context.l10n('customer_card_no_notes'),
                    style: TextStyle(
                      color: notes.isNotEmpty 
                          ? (context.appColors.ink) 
                          : (context.appColors.ink3),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 把大頭貼網址（一般網址或 Base64 資料）轉成圖片來源；空字串回傳 null
ImageProvider? customerAvatarProvider(String avatarUrl) {
  if (avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}
