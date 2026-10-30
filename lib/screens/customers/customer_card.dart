import 'package:flutter/material.dart';
import '../../services/customer_card_summary_service.dart';
import '../../services/tag_categorizer.dart';
import 'customer_status_widgets.dart';
import '../../theme/app_theme.dart';

/// 客戶卡片（2026-10-30 組長提出：拿掉翻面，點一下就打開側邊欄）
///
/// 原本翻到背面才有的放大、編輯、刪除、人脈關聯，全部移到側邊欄上方。
/// 點卡片時把「卡片在畫面上的位置」交給 [onOpen]，讓卡片能從這裡飛到左邊。
class CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final void Function(Rect cardRect) onOpen;

  /// 飛到左邊的那張的複製品不要跟著藏起來
  final bool hideWhenFlying;

  const CustomerCard({super.key, required this.customer, required this.onOpen, this.hideWhenFlying = true});

  /// 正在飛到左邊的客戶：原本位置的卡片先藏起來。
  /// 用通知的方式只讓那一張卡片重畫，不讓整頁重畫（2026-10-30 量到起飛時整頁重畫會掉格）
  static final ValueNotifier<String?> flyingCustomerId = ValueNotifier(null);

  // 列表裡每張卡片的定位鑰匙：飛回去時用來找卡片「現在」的位置
  static final Map<String, GlobalKey> _positionKeys = {};

  /// 列表裡這位客戶的卡片現在在畫面上的位置；不在畫面上回傳 null
  static Rect? liveRectOf(String customerId) {
    final RenderObject? renderObject = _positionKeys[customerId]?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  // 卡片在整個畫面上的位置與大小
  Rect? _cardRectOnScreen(BuildContext context) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final Offset topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = _buildCard(context);
    if (!hideWhenFlying) return card;
    final String customerId = customer['id'].toString();
    final GlobalKey positionKey = _positionKeys.putIfAbsent(customerId, () => GlobalKey());
    return ValueListenableBuilder<String?>(
      key: positionKey,
      valueListenable: flyingCustomerId,
      builder: (BuildContext context, String? flyingId, Widget? child) {
        return Opacity(opacity: flyingId == customerId ? 0 : 1, child: child);
      },
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final AppColors colors = context.appColors;
    final String name = customer['name']?.toString() ?? '';
    final String nickname = customer['nickname']?.toString() ?? '';
    String displayName = name;
    if (nickname.isNotEmpty) displayName = '$name ($nickname)';

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.line),
      ),
      child: Builder(
        builder: (BuildContext cardContext) => InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            final Rect? cardRect = _cardRectOnScreen(cardContext);
            if (cardRect != null) onOpen(cardRect);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CustomerCardHeader(customer: customer, displayName: displayName),
                const SizedBox(height: 10),
                Divider(height: 1, color: colors.line),
                const SizedBox(height: 8),
                _CustomerSummaryLines(customerId: customer['id'].toString(), customerName: name),
                const Spacer(),
                _CustomerTagRow(tags: List<dynamic>.from(customer['tags'] ?? const [])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 頭像＋名字（含狀態）＋電話（信箱點開側邊欄再看，卡片不擠）
class _CustomerCardHeader extends StatelessWidget {
  final Map<String, dynamic> customer;
  final String displayName;

  const _CustomerCardHeader({required this.customer, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String name = customer['name']?.toString() ?? '';
    final String avatarUrl = customer['avatar_url']?.toString() ?? '';
    String nameInitial = '?';
    if (name.isNotEmpty) nameInitial = name.substring(0, 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colors.acc.withValues(alpha: 0.12),
          radius: 24,
          backgroundImage: customerAvatarProvider(avatarUrl),
          child: avatarUrl.isEmpty
              ? Text(nameInitial, style: TextStyle(color: colors.acc, fontWeight: FontWeight.bold, fontSize: 18))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerNameWithStatus(
                name: displayName,
                status: customer['client_status'] as String?,
                style: TextStyle(color: colors.ink, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _ContactLine(icon: Icons.phone, text: customer['phone']?.toString() ?? '未填寫'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final Color color = context.appColors.ink3;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// 兩行摘要：保單狀況、下次行程（資料讀到後自動更新）
class _CustomerSummaryLines extends StatelessWidget {
  final String customerId;
  final String customerName;

  const _CustomerSummaryLines({required this.customerId, required this.customerName});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, CustomerCardSummary>>(
      valueListenable: CustomerCardSummaryService.instance.summaries,
      builder: (BuildContext context, Map<String, CustomerCardSummary> summaries, Widget? child) {
        final CustomerCardSummary summary = CustomerCardSummaryService.instance.summaryOf(customerId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContactLine(icon: Icons.verified_user_outlined, text: summary.policyText),
            const SizedBox(height: 4),
            _ContactLine(icon: Icons.event_outlined, text: summary.nextEventText(customerName, DateTime.now())),
          ],
        );
      },
    );
  }
}

/// 最多顯示 3 個標籤，顏色依標籤分類
class _CustomerTagRow extends StatelessWidget {
  final List<dynamic> tags;

  const _CustomerTagRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> chips = [];
    for (final dynamic tag in tags.take(3)) {
      final style = TagCategorizer.getStyle(tag.toString(), isDark);
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: style.backgroundColor, borderRadius: BorderRadius.circular(6)),
        child: Text(tag.toString(), style: TextStyle(color: style.textColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ));
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}
