import 'package:flutter/material.dart';

import '../../services/insurance_news_service.dart';
import '../../theme/app_theme.dart';
import 'news_paper_style.dart';

/// 「前一天焦點」：當天話題少時放在報紙最下面，只有熱度、標題、主要報導，字比較小（2026-10-31 沛沛決定）
class NewsPreviousTopicsSection extends StatelessWidget {
  final List<InsuranceNewsTopic> topics;
  final bool isWide;

  const NewsPreviousTopicsSection({super.key, required this.topics, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(text: '前一天焦點'),
        const SizedBox(height: 12),
        if (isWide) _buildColumns(context) else _buildSingleColumn(context),
      ],
    );
  }

  // 電腦：一排三則，欄與欄之間細線
  Widget _buildColumns(BuildContext context) {
    final Color ruleColor = NewsPaperStyle.rule(context);
    final List<Widget> rows = [];
    for (int start = 0; start < topics.length; start += 3) {
      if (rows.isNotEmpty) {
        rows.add(Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: ruleColor)));
      }
      final List<Widget> cells = [];
      for (int column = 0; column < 3; column++) {
        if (column > 0) cells.add(VerticalDivider(width: 1, thickness: 0.8, color: ruleColor));
        final int index = start + column;
        Widget cell = const SizedBox.shrink();
        if (index < topics.length) cell = _PreviousTopicItem(topic: topics[index]);
        double leftPadding = 16;
        if (column == 0) leftPadding = 0;
        double rightPadding = 16;
        if (column == 2) rightPadding = 0;
        cells.add(Expanded(child: Padding(padding: EdgeInsets.only(left: leftPadding, right: rightPadding), child: cell)));
      }
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  // 手機：一欄
  Widget _buildSingleColumn(BuildContext context) {
    final Color ruleColor = NewsPaperStyle.rule(context);
    final List<Widget> items = [];
    for (final InsuranceNewsTopic topic in topics) {
      if (items.isNotEmpty) {
        items.add(Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: ruleColor)));
      }
      items.add(_PreviousTopicItem(topic: topic));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

/// 區塊標題：左右兩條細線夾著宋體小標，像報紙的版名
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final Color ruleColor = context.appColors.ink;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ruleColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: NewsPaperStyle.headline(context, 15).copyWith(letterSpacing: 4)),
        ),
        Expanded(child: Container(height: 1, color: ruleColor)),
      ],
    );
  }
}

class _PreviousTopicItem extends StatelessWidget {
  final InsuranceNewsTopic topic;

  const _PreviousTopicItem({required this.topic});

  @override
  Widget build(BuildContext context) {
    final InsuranceNewsArticle? primaryArticle = topic.primaryArticle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NewsHeatMeter(articleCount: topic.articles.length),
        const SizedBox(height: 4),
        Text(topic.topicTitle, style: NewsPaperStyle.headline(context, 15)),
        if (primaryArticle != null) NewsArticleLine(article: primaryArticle),
      ],
    );
  }
}
