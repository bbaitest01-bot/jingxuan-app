import 'package:flutter/material.dart';

import '../../services/insurance_news_service.dart';
import '../../theme/app_theme.dart';
import 'news_paper_style.dart';
import 'news_previous_topics.dart';
import 'news_topic_columns.dart';
import 'news_topic_story.dart';

/// 經選日報頭版（2026-10-31 沛沛選：報紙頭版＋報導熱度）
///
/// 寬畫面：報頭 → 左「今日大勢」（總覽直接全部顯示）＋右第一則話題（頭版大圖，約四成寬）
/// → 其他話題分三欄往下排（`NewsTopicColumns`，三欄長度差不多，不留大片空白）。
/// 窄畫面（手機）：報頭、雙線、宋體都保留，話題改一欄、字放大（2026-10-31 沛沛：手機也要好看、好讀）。
class NewsFrontPage extends StatelessWidget {
  final InsuranceNewsEdition edition;

  const NewsFrontPage({super.key, required this.edition});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 760;
        final List<InsuranceNewsTopic> topics = edition.topics;
        final List<InsuranceNewsTopic> restTopics = topics.skip(1).toList();
        EdgeInsets padding = const EdgeInsets.fromLTRB(14, 14, 14, 18);
        if (isWide) padding = const EdgeInsets.fromLTRB(28, 22, 28, 28);

        return NewsPaperSheet(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NewsMasthead(edition: edition, isWide: isWide),
              SizedBox(height: isWide ? 18 : 12),
              _buildLeadSection(context, isWide),
              if (restTopics.isNotEmpty) ...[
                SizedBox(height: isWide ? 18 : 12),
                const NewsDoubleRule(),
                SizedBox(height: isWide ? 14 : 10),
                if (isWide)
                  NewsTopicColumns(topics: restTopics, totalTopicCount: topics.length)
                else
                  NewsTopicSingleColumn(topics: restTopics),
              ],
              if (edition.previousTopics.isNotEmpty) ...[
                SizedBox(height: isWide ? 24 : 16),
                NewsPreviousTopicsSection(topics: edition.previousTopics, isWide: isWide),
              ],
            ],
          ),
        );
      },
    );
  }

  // 頭版上半：今日大勢（左）＋第一則話題（右）；手機上下排
  Widget _buildLeadSection(BuildContext context, bool isWide) {
    final Widget leadStory = _DailyTrendStory(edition: edition, isWide: isWide);
    if (edition.topics.isEmpty) return leadStory;
    final Widget featuredStory = NewsTopicStory(
      topic: edition.topics.first,
      size: NewsStorySize.featured,
      isCompact: !isWide,
      imageSize: NewsImageSize.large,
    );
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leadStory,
          const SizedBox(height: 12),
          Divider(height: 1, color: NewsPaperStyle.rule(context)),
          const SizedBox(height: 12),
          featuredStory,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 22), child: leadStory)),
          VerticalDivider(width: 1, thickness: 0.8, color: NewsPaperStyle.rule(context)),
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(left: 22), child: featuredStory)),
        ],
      ),
    );
  }
}

/// 報頭：「經選日報」＋雙線＋日期、更新時間、話題與報導數
class _NewsMasthead extends StatelessWidget {
  final InsuranceNewsEdition edition;
  final bool isWide;

  const _NewsMasthead({required this.edition, required this.isWide});

  static const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final DateTime? updatedAt = edition.updatedAt;
    final DateTime today = updatedAt ?? DateTime.now();
    final String dateText = '${today.year} 年 ${today.month} 月 ${today.day} 日 星期${_weekdayNames[today.weekday - 1]}';
    String updateText = '尚未更新';
    if (updatedAt != null) {
      final String hour = updatedAt.hour.toString().padLeft(2, '0');
      final String minute = updatedAt.minute.toString().padLeft(2, '0');
      updateText = '$hour:$minute 更新';
    }
    final String countText = '${edition.topics.length} 則話題・${edition.articleCount} 篇報導';
    final TextStyle metaStyle = TextStyle(fontSize: isWide ? 12 : 10.5, color: colors.ink3);

    final List<Widget> metaItems = [Text(dateText, style: metaStyle)];
    if (isWide) metaItems.add(Text('保險業每日焦點', style: metaStyle));
    metaItems.add(Text('$updateText・$countText', style: metaStyle));

    return Column(
      children: [
        Text(
          '經選日報',
          textAlign: TextAlign.center,
          style: AppTextStyles.serif(fontSize: isWide ? 34 : 24, color: colors.ink).copyWith(letterSpacing: isWide ? 8 : 4),
        ),
        const SizedBox(height: 6),
        const NewsDoubleRule(),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: metaItems),
      ],
    );
  }
}

/// 頭條：今日大勢一句話當大標題，總覽直接全部顯示（2026-10-31 沛沛：展開也不佔空間，不必收起來）
class _DailyTrendStory extends StatelessWidget {
  final InsuranceNewsEdition edition;
  final bool isWide;

  const _DailyTrendStory({required this.edition, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String trend = edition.dailyTrend;
    final String overview = edition.dailyOverview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: scheme.error,
          child: Text('今日大勢', style: TextStyle(fontSize: 11, color: scheme.onError, letterSpacing: 2)),
        ),
        const SizedBox(height: 10),
        if (trend.isNotEmpty) Text(trend, style: NewsPaperStyle.headline(context, isWide ? 25 : 19, color: colors.acc)),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(overview, style: NewsPaperStyle.body(context, fontSize: isWide ? 14 : 15)),
        ],
      ],
    );
  }
}
