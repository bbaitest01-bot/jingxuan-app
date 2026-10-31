import 'package:flutter/material.dart';

import '../../services/customer_card_summary_service.dart';
import '../../services/tag_categorizer.dart';
import '../../theme/app_theme.dart';
import 'customer_status_widgets.dart';

/// 點開客戶後飛到左邊、放大的那張卡片的內容（2026-11-01 沛沛定案）
///
/// 只放每位客戶都有、看了不會有疑問的資料，排成「左邊小標、右邊內容」的對齊表格：
/// 客戶階段、下次行程、電話、Email、建檔；沒填的寫「未填」，每張行數一樣，不會一邊空一邊滿。
/// 介紹人放在名字下面，標籤全部放最下面。
/// 卡片高度固定（見 CustomerCardFlight.landingCardHeight），剛好放得下表格。
class CustomerCardDetailsBody extends StatelessWidget {
  final Map<String, dynamic> customer;
  final String displayName;

  const CustomerCardDetailsBody({super.key, required this.customer, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String customerId = customer['id'].toString();
    final String name = customer['name']?.toString() ?? '';
    return ValueListenableBuilder<Map<String, CustomerCardSummary>>(
      valueListenable: CustomerCardSummaryService.instance.summaries,
      builder: (BuildContext context, Map<String, CustomerCardSummary> summaries, Widget? child) {
        final CustomerCardSummary summary = CustomerCardSummaryService.instance.summaryOf(customerId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailsHeader(customer: customer, displayName: displayName, referrerName: summary.referrerName ?? ''),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 10),
            _DetailsRow(label: '客戶階段', value: summary.policyText),
            _DetailsRow(label: '下次行程', value: summary.nextEventText(name, DateTime.now())),
            _DetailsRow(label: '電話', value: customer['phone']?.toString() ?? '', isNumber: true),
            _DetailsRow(label: 'Email', value: customer['email']?.toString() ?? ''),
            _DetailsRow(label: '建檔', value: _createdText(customer['created_at']?.toString())),
            const Spacer(),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 10),
            _AllTags(tags: List<dynamic>.from(customer['tags'] ?? const [])),
          ],
        );
      },
    );
  }

  // 「2026/10/14・已 18 天」；今天建的寫「今天建檔」
  static String _createdText(String? createdAtText) {
    final DateTime? createdAt = DateTime.tryParse(createdAtText ?? '');
    if (createdAt == null) return '';
    final DateTime local = createdAt.toLocal();
    final DateTime now = DateTime.now();
    final int days =
        DateTime(now.year, now.month, now.day).difference(DateTime(local.year, local.month, local.day)).inDays;
    final String date = '${local.year}/${local.month}/${local.day}';
    if (days <= 0) return '$date・今天建檔';
    return '$date・已 $days 天';
  }
}

/// 頭像＋名字（含狀態）＋介紹人小字
class _DetailsHeader extends StatelessWidget {
  final Map<String, dynamic> customer;
  final String displayName;
  final String referrerName;

  const _DetailsHeader({required this.customer, required this.displayName, required this.referrerName});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String name = customer['name']?.toString() ?? '';
    final String avatarUrl = customer['avatar_url']?.toString() ?? '';
    String nameInitial = '?';
    if (name.isNotEmpty) nameInitial = name.substring(0, 1);
    return Row(
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
              if (referrerName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('由 $referrerName 介紹', style: TextStyle(fontSize: 11, color: colors.ink3)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 表格的一列：左邊固定寬的小標，右邊內容；沒資料寫「未填」（淡色）
class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isNumber;

  const _DetailsRow({required this.label, required this.value, this.isNumber = false});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String text = value.trim();
    TextStyle valueStyle = TextStyle(fontSize: 12, color: colors.ink);
    if (isNumber) valueStyle = AppTextStyles.mono(fontSize: 12, color: colors.ink);
    String shownText = text;
    if (text.isEmpty) {
      shownText = '未填';
      valueStyle = TextStyle(fontSize: 12, color: colors.ink3);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: TextStyle(fontSize: 11, color: colors.ink3))),
          Expanded(child: Text(shownText, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// 全部標籤（最多 6 個，只排一行）；沒有標籤寫「還沒有標籤」
class _AllTags extends StatelessWidget {
  final List<dynamic> tags;

  const _AllTags({required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text('還沒有標籤', style: TextStyle(fontSize: 11, color: context.appColors.ink3));
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> chips = [];
    for (final dynamic tag in tags.take(6)) {
      final style = TagCategorizer.getStyle(tag.toString(), isDark);
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: style.backgroundColor, borderRadius: BorderRadius.circular(6)),
        child:
            Text(tag.toString(), style: TextStyle(color: style.textColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ));
    }
    // 只排一行，放不下的切掉：卡片高度貼合內容，標籤換行會擠出卡片
    return SizedBox(
      height: 22,
      child: ClipRect(child: Wrap(spacing: 6, runSpacing: 4, clipBehavior: Clip.hardEdge, children: chips)),
    );
  }
}
