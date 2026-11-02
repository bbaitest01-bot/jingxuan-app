import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/insurance_news_service.dart';
import '../../theme/app_theme.dart';
import 'news_paper_style.dart';

/// 焦點追蹤（前日話題／重大專題）：
/// 緊湊飽滿、消滅空白、自適應文字量：
/// 1. 不放圖（純文字深度追蹤，維持版面乾淨嚴肅）
/// 2. 移除 Emoji（不使用 🚨 等掉價貼圖）
/// 3. 動態分欄，摘要文字多長就佔多高，媒體原稿直接緊隨其後，徹底消滅大片灰色留白！
class NewsPreviousTopicsSection extends StatelessWidget {
  final List<InsuranceNewsTopic> topics;
  final bool isWide;

  const NewsPreviousTopicsSection({super.key, required this.topics, required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) return const SizedBox.shrink();

    final String leadCategory = topics.first.category.isNotEmpty ? topics.first.category : '保險焦點';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(category: leadCategory),
        const SizedBox(height: 14),
        if (isWide) _buildWideColumns(context) else _buildMobileList(context),
      ],
    );
  }

  Widget _buildWideColumns(BuildContext context) {
    final int columnCount = math.min(topics.length, 3).clamp(1, 3);
    final Color ruleColor = NewsPaperStyle.rule(context);
    final List<Widget> columns = [];

    for (int col = 0; col < columnCount; col++) {
      if (col > 0) columns.add(VerticalDivider(width: 1, thickness: 0.8, color: ruleColor));
      final List<Widget> colItems = [];
      for (int i = col; i < topics.length; i += columnCount) {
        if (colItems.isNotEmpty) {
          colItems.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: ruleColor),
          ));
        }
        colItems.add(_PreviousTopicCard(topic: topics[i], isLead: i == 0 && columnCount == 1));
      }
      columns.add(Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            left: col == 0 ? 0 : 16,
            right: col == columnCount - 1 ? 0 : 16,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: colItems),
        ),
      ));
    }
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns));
  }

  Widget _buildMobileList(BuildContext context) {
    final Color ruleColor = NewsPaperStyle.rule(context);
    final List<Widget> items = [];
    for (int i = 0; i < topics.length; i++) {
      if (i > 0) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: ruleColor),
        ));
      }
      items.add(_PreviousTopicCard(topic: topics[i], isLead: i == 0));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

/// 區塊標頭：深紅底「焦點追蹤」徽章＋典雅副標＋細線貫穿（零 Emoji）
class _SectionHeader extends StatelessWidget {
  final String category;

  const _SectionHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    final Color ruleColor = NewsPaperStyle.rule(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF991B1B), // 統一深紅底
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Text(
            '焦點追蹤',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '〔 重大$category深入追蹤・延伸閱讀 〕',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF450A0A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: ruleColor)),
      ],
    );
  }
}

/// 單則焦點話題卡片：標籤、熱度、標題、摘要、媒體原稿緊湊排列，絕無巨大空白
class _PreviousTopicCard extends StatelessWidget {
  final InsuranceNewsTopic topic;
  final bool isLead;

  const _PreviousTopicCard({required this.topic, this.isLead = false});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String summary = topic.aiSummary.isNotEmpty ? topic.aiSummary.trim() : topic.shortSummary.trim();
    final double headlineSize = isLead ? 18.5 : 16.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分類標籤與熱度
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // 實心深墨藍底標籤
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                topic.category.isNotEmpty ? topic.category : '即時要聞',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            NewsHeatMeter(articleCount: topic.articles.length),
          ],
        ),
        const SizedBox(height: 6),
        // 標題
        Text(
          topic.topicTitle,
          style: NewsPaperStyle.headline(context, headlineSize, color: colors.ink).copyWith(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        if (topic.shortSummary.isNotEmpty && topic.shortSummary != summary) ...[
          const SizedBox(height: 4),
          Text(
            '── ${topic.shortSummary}',
            style: NewsPaperStyle.body(context, fontSize: 13).copyWith(
              color: colors.ink2,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            summary,
            textAlign: TextAlign.justify,
            style: NewsPaperStyle.body(context, fontSize: 13.5).copyWith(
              height: 1.75,
            ),
          ),
        ],
        // 媒體來源緊接在後，緊湊乾淨
        if (topic.articles.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...topic.articles.take(3).map((InsuranceNewsArticle article) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: NewsArticleLine(article: article),
          )),
        ],
      ],
    );
  }
}
