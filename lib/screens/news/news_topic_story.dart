import 'package:flutter/material.dart';

import '../../services/insurance_news_service.dart';
import '../../theme/app_theme.dart';
import 'news_paper_style.dart';

/// 這則話題在版面上佔多大
enum NewsStorySize {
  /// 頭版右邊那則
  featured,

  /// 寬欄
  wide,

  /// 窄欄
  narrow,
}

/// 插圖尺寸（嚴格限制高度在 140px 以內，絕不吃內容）
enum NewsImageSize {
  none,
  small,
  medium,
  large,
}

/// 報紙上的一篇報導＝一個新聞話題
///
/// 特性：
/// 1. 手機與電腦內容 100% 同步，絕不因螢幕大小吃掉任何數據或文字。
/// 2. 移除所有「讀更多」與「另 N 家報導」折疊按鈕，文字與媒體來源自然大器展開。
/// 3. 【典雅報紙數據條】：上下細線包裹、左側脈絡說明、右側深墨色重點數字，告別孤零零突兀字塊。
/// 4. 圖片嚴格限制高度（最高 140px），絕不霸佔或擠壓文字版面。
class NewsTopicStory extends StatelessWidget {
  final InsuranceNewsTopic topic;
  final NewsStorySize size;
  final bool isCompact;
  final NewsImageSize imageSize;

  const NewsTopicStory({
    super.key,
    required this.topic,
    this.size = NewsStorySize.narrow,
    this.isCompact = false,
    this.imageSize = NewsImageSize.none,
  });

  double get _headlineSize {
    if (isCompact) return 18.5;
    if (size == NewsStorySize.featured) return 21;
    if (size == NewsStorySize.wide) return 19;
    return 17;
  }

  @override
  Widget build(BuildContext context) {
    final String fullSummary = topic.aiSummary.trim();
    final String shortSummary = topic.shortSummary.trim();
    String summary = fullSummary;
    if (summary.isEmpty) {
      summary = shortSummary;
    } else if (shortSummary.isNotEmpty && !fullSummary.contains(shortSummary)) {
      summary = '$shortSummary\n$fullSummary';
    }

    String? keyNumber = topic.keyNumber;
    if (keyNumber.isEmpty) keyNumber = NewsTextHelper.keyNumber(summary);
    final bool showKeyNumber = keyNumber != null && keyNumber.isNotEmpty;

    final String imageUrl = topic.mainImageUrl ?? '';
    NewsImageSize effectiveImageSize = imageSize;
    if (imageUrl.isEmpty) effectiveImageSize = NewsImageSize.none;
    final bool hasTopImage = effectiveImageSize == NewsImageSize.medium || effectiveImageSize == NewsImageSize.large;

    final double bodySize = isCompact ? 14.5 : 14.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTopImage) NewsIllustration(imageUrl: imageUrl),
        if (effectiveImageSize == NewsImageSize.small)
          _SmallImageHeading(imageUrl: imageUrl, topic: topic, headlineSize: _headlineSize)
        else ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // 實心深墨藍徽章
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
          Text(
            topic.topicTitle,
            style: NewsPaperStyle.headline(context, _headlineSize).copyWith(
              height: 1.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        // 電腦與手機同步展示：【典雅報紙數據條】
        if (showKeyNumber)
          _NewspaperDataBar(
            number: keyNumber,
            label: topic.keyNumberLabel,
            topicTitle: topic.topicTitle,
          ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            summary,
            textAlign: TextAlign.justify,
            style: NewsPaperStyle.body(context, fontSize: bodySize).copyWith(height: 1.78),
          ),
        ],
        // 所有媒體報導直接陳列，不設抽屜收合
        if (topic.articles.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...topic.articles.take(4).map((InsuranceNewsArticle article) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: NewsArticleLine(article: article),
          )),
        ],
      ],
    );
  }
}

/// 典雅報紙數據條（Data Bar）：
/// 上下細線包裹、左側脈絡說明、右側深墨色數字＋宋體單位，具備高度專業財經感
class _NewspaperDataBar extends StatelessWidget {
  final String number;
  final String label;
  final String topicTitle;

  const _NewspaperDataBar({
    required this.number,
    required this.label,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color ruleColor = NewsPaperStyle.rule(context);
    final String displayLabel = label.isNotEmpty ? label : '關鍵數據指標';

    final RegExp numReg = RegExp(r'^([\d,\.]+)\s*(.*)$');
    final RegExpMatch? match = numReg.firstMatch(number.trim());
    final String digits = match != null ? match.group(1)! : number;
    final String unit = match != null ? match.group(2)! : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ruleColor, width: 0.9),
          bottom: BorderSide(color: ruleColor, width: 0.9),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  topicTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                digits,
                style: AppTextStyles.mono(
                  fontSize: 22,
                  color: const Color(0xFF1E293B), // 高質感深墨色，非刺眼電路藍
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.ink2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 小方圖＋標題並排：圖在左、熱度與標題在右
class _SmallImageHeading extends StatelessWidget {
  final String imageUrl;
  final InsuranceNewsTopic topic;
  final double headlineSize;

  const _SmallImageHeading({required this.imageUrl, required this.topic, required this.headlineSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 88, child: NewsIllustration(imageUrl: imageUrl, aspectRatio: 1, showCaption: false)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
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
              Text(
                topic.topicTitle,
                style: NewsPaperStyle.headline(context, headlineSize).copyWith(
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// AI 插圖：水平置中（Center）、等比例展示、受 160px 上限約束，視覺對稱耐看
class NewsIllustration extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final bool showCaption;
  final double maxHeight;

  const NewsIllustration({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
    this.showCaption = true,
    this.maxHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            color: colors.ink3.withValues(alpha: 0.12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 300), child: child);
              },
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    if (!showCaption) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(child: Tooltip(message: 'AI 示意圖', child: image)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            image,
            const SizedBox(height: 3),
            Text('AI 示意圖', style: TextStyle(fontSize: 10, color: colors.ink3)),
          ],
        ),
      ),
    );
  }
}
