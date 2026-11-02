import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/insurance_news_service.dart';
import 'news_paper_style.dart';
import 'news_topic_story.dart';

/// 頭版下半的話題：像真的報紙一樣分三欄往下排，每則放進「目前最短」的那一欄，
/// 三欄長度差不多，不會出現一排裡某格很長、旁邊留大片空白（2026-10-31 沛沛反映左下角總是空的）。
///
/// 圖少而精（2026-10-31 沛沛決定）：中、小圖加起來約「話題數的一半」、最多 5 張；
/// 報導家數多的話題優先放中圖，其他放小方圖；同一欄不連續放兩張圖。
class NewsTopicColumns extends StatelessWidget {
  final List<InsuranceNewsTopic> topics;

  /// 今天全部話題數（含頭版那則），用來決定放幾張圖
  final int totalTopicCount;

  const NewsTopicColumns({super.key, required this.topics, required this.totalTopicCount});

  static const int _columnCount = 3;
  static const double _columnGap = 18;

  /// 決定哪幾則放圖：做法 A，有圖話題放寬為 160px 完整置中中圖，充實版面平衡高度！
  /// 嚴格去重：相同圖片 URL 絕不重複出現兩次！
  static Map<String, NewsImageSize> planImageSizes(List<InsuranceNewsTopic> topics) {
    final Map<String, NewsImageSize> plan = {};
    final Set<String> usedImageUrls = {};

    for (final InsuranceNewsTopic topic in topics) {
      final String imgUrl = (topic.mainImageUrl ?? '').trim();
      if (imgUrl.isEmpty || usedImageUrls.contains(imgUrl)) {
        plan[topic.id] = NewsImageSize.none;
        continue;
      }
      usedImageUrls.add(imgUrl);
      plan[topic.id] = NewsImageSize.medium;
    }
    return plan;
  }

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) return const SizedBox.shrink();
    // 動態欄數：2 則話題就分 2 欄（每欄 50%），徹底消除第 3 欄大片空白！
    final int columnCount = math.min(topics.length, _columnCount).clamp(1, 3);
    final Map<String, NewsImageSize> imagePlan = planImageSizes(topics);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double columnWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - _columnGap * 2 * (columnCount - 1)) / columnCount;
        final List<List<Widget>> columns = List.generate(columnCount, (int index) => <Widget>[]);
        final List<double> columnHeights = List.filled(columnCount, 0);
        final List<bool> lastHadImage = List.filled(columnCount, false);
        final Color ruleColor = NewsPaperStyle.rule(context);

        for (final InsuranceNewsTopic topic in topics) {
          final NewsImageSize imageSize = imagePlan[topic.id] ?? NewsImageSize.none;
          final bool hasImage = imageSize != NewsImageSize.none;
          final int column = _pickColumn(columnHeights, lastHadImage, hasImage);
          if (columns[column].isNotEmpty) {
            columns[column].add(Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: ruleColor)));
            columnHeights[column] += 29;
          }
          columns[column].add(NewsTopicStory(topic: topic, imageSize: imageSize));
          columnHeights[column] += _estimateHeight(topic, imageSize, columnWidth);
          lastHadImage[column] = hasImage;
        }

        final List<Widget> rowChildren = [];
        for (int column = 0; column < columnCount; column++) {
          if (column > 0) rowChildren.add(VerticalDivider(width: 1, thickness: 0.8, color: ruleColor));
          double leftPadding = _columnGap;
          if (column == 0) leftPadding = 0;
          double rightPadding = _columnGap;
          if (column == columnCount - 1) rightPadding = 0;
          rowChildren.add(Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns[column]),
            ),
          ));
        }
        return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren));
      },
    );
  }

  // 放進最短的一欄；有圖的話，避開上一則也有圖的欄（差不多短的欄裡挑）
  static int _pickColumn(List<double> heights, List<bool> lastHadImage, bool hasImage) {
    int shortest = 0;
    for (int index = 1; index < heights.length; index++) {
      if (heights[index] < heights[shortest]) shortest = index;
    }
    if (!hasImage || !lastHadImage[shortest]) return shortest;
    int best = -1;
    for (int index = 0; index < heights.length; index++) {
      if (lastHadImage[index]) continue;
      if (best == -1 || heights[index] < heights[best]) best = index;
    }
    // 其他欄長太多（多過 200）就還是放最短的那欄
    if (best == -1 || heights[best] - heights[shortest] > 200) return shortest;
    return best;
  }

  // 粗估一則話題排出來多高（只用來決定放哪一欄，不用很準）
  static double _estimateHeight(InsuranceNewsTopic topic, NewsImageSize imageSize, double width) {
    final double titleCharsPerLine = math.max(6, width / 16);
    final double bodyCharsPerLine = math.max(8, width / 13.5);
    String summary = topic.shortSummary;
    if (summary.isEmpty) summary = NewsTextHelper.firstSentences(topic.aiSummary, 1);
    double height = 22;
    height += (topic.topicTitle.length / titleCharsPerLine).ceil() * 22;
    height += (summary.length / bodyCharsPerLine).ceil() * 24 + 30;
    height += 44;
    if (topic.articles.length > 1) height += 24;
    if (imageSize == NewsImageSize.medium) height += 168;
    if (imageSize == NewsImageSize.small) height += 40;
    if (imageSize == NewsImageSize.none && topic.keyNumber.isNotEmpty) height += 52;
    return height;
  }
}

/// 手機的其他話題：一欄往下讀，內容與配圖與電腦版 100% 同步
class NewsTopicSingleColumn extends StatelessWidget {
  final List<InsuranceNewsTopic> topics;

  const NewsTopicSingleColumn({super.key, required this.topics});

  @override
  Widget build(BuildContext context) {
    final Color ruleColor = NewsPaperStyle.rule(context);
    final Map<String, NewsImageSize> imagePlan = NewsTopicColumns.planImageSizes(topics);
    final List<Widget> items = [];
    for (int index = 0; index < topics.length; index++) {
      if (items.isNotEmpty) {
        items.add(Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: ruleColor)));
      }
      final NewsImageSize imageSize = imagePlan[topics[index].id] ?? NewsImageSize.none;
      items.add(NewsTopicStory(
        topic: topics[index],
        isCompact: true,
        imageSize: imageSize,
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}
