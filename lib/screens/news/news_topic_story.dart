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

/// 這則話題的插圖要多大（2026-10-31 沛沛：頭版一張精緻大圖，下面中、小圖散落，大小不固定）
enum NewsImageSize {
  /// 不放圖
  none,

  /// 小方圖：放在標題左邊
  small,

  /// 中圖：欄寬、4:3，放在最上面
  medium,

  /// 頭版大圖：4:3，放在最上面
  large,
}

/// 報紙上的一篇報導＝一個新聞話題（2026-10-31 沛沛選報紙版）
///
/// 從上到下：（中、大圖）AI 插圖 → 報導熱度 → 宋體標題（小方圖時圖在標題左邊）→（窄欄沒圖時）關鍵數字 → 短重點 → 主要報導一行 → 「另 N 家報導」。
/// 短重點優先用 AI 寫的一句話；舊資料沒有時，依大小取前一兩句。「讀更多」在原地看完整重點（2026-10-31 沛沛反映字太多）。
class NewsTopicStory extends StatefulWidget {
  final InsuranceNewsTopic topic;
  final NewsStorySize size;

  /// 手機：一欄、字放大
  final bool isCompact;

  /// 插圖大小；這則沒有圖時一律不顯示
  final NewsImageSize imageSize;

  const NewsTopicStory({
    super.key,
    required this.topic,
    this.size = NewsStorySize.narrow,
    this.isCompact = false,
    this.imageSize = NewsImageSize.none,
  });

  @override
  State<NewsTopicStory> createState() => _NewsTopicStoryState();
}

class _NewsTopicStoryState extends State<NewsTopicStory> {
  bool _showFullSummary = false;
  bool _showOtherArticles = false;

  double get _headlineSize {
    if (widget.isCompact) return 19;
    if (widget.size == NewsStorySize.featured) return 20;
    if (widget.size == NewsStorySize.wide) return 19;
    return 16;
  }

  int get _sentenceCount {
    if (widget.size == NewsStorySize.narrow && !widget.isCompact) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceNewsTopic topic = widget.topic;
    final InsuranceNewsArticle? primaryArticle = topic.primaryArticle;
    final List<InsuranceNewsArticle> otherArticles = topic.otherArticles;
    final String fullSummary = topic.aiSummary.trim();
    String shortSummary = topic.shortSummary;
    if (shortSummary.isEmpty) shortSummary = NewsTextHelper.firstSentences(fullSummary, _sentenceCount);
    final bool isTruncated = fullSummary.isNotEmpty && shortSummary != fullSummary;
    String summaryText = shortSummary;
    if (_showFullSummary) summaryText = fullSummary;
    String? keyNumber = topic.keyNumber;
    if (keyNumber.isEmpty) keyNumber = NewsTextHelper.keyNumber(fullSummary);
    final String imageUrl = topic.mainImageUrl ?? '';
    NewsImageSize imageSize = widget.imageSize;
    if (imageUrl.isEmpty) imageSize = NewsImageSize.none;
    final bool hasImage = imageSize != NewsImageSize.none;
    final bool hasTopImage = imageSize == NewsImageSize.medium || imageSize == NewsImageSize.large;
    // 有圖就不再放大數字，避免擠
    final bool showKeyNumber = keyNumber != null && widget.size == NewsStorySize.narrow && !hasImage;
    double bodySize = 13.5;
    if (widget.isCompact) bodySize = 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTopImage) NewsIllustration(imageUrl: imageUrl),
        if (imageSize == NewsImageSize.small)
          _SmallImageHeading(imageUrl: imageUrl, topic: topic, headlineSize: _headlineSize)
        else ...[
          NewsHeatMeter(articleCount: topic.articles.length),
          const SizedBox(height: 6),
          Text(topic.topicTitle, style: NewsPaperStyle.headline(context, _headlineSize)),
        ],
        if (showKeyNumber) _KeyNumber(text: keyNumber, label: topic.keyNumberLabel),
        if (summaryText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(summaryText, style: NewsPaperStyle.body(context, fontSize: bodySize)),
        ],
        if (isTruncated)
          _InlineToggle(
            label: _showFullSummary ? '收起' : '讀更多',
            isOpen: _showFullSummary,
            onTap: () => setState(() => _showFullSummary = !_showFullSummary),
          ),
        if (primaryArticle != null) ...[
          const SizedBox(height: 6),
          NewsArticleLine(article: primaryArticle),
        ],
        if (otherArticles.isNotEmpty) ...[
          _InlineToggle(
            label: _showOtherArticles ? '收起其他報導' : '另 ${otherArticles.length} 家報導',
            isOpen: _showOtherArticles,
            onTap: () => setState(() => _showOtherArticles = !_showOtherArticles),
          ),
          if (_showOtherArticles) _OtherArticlesList(articles: otherArticles),
        ],
      ],
    );
  }
}

/// 關鍵數字：大大的藍色數字，下面一行小字說明（像報紙的資訊圖）
class _KeyNumber extends StatelessWidget {
  final String text;
  final String label;

  const _KeyNumber({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppTextStyles.mono(fontSize: 26, color: colors.acc)),
          if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 11, color: colors.ink3)),
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
              NewsHeatMeter(articleCount: topic.articles.length),
              const SizedBox(height: 6),
              Text(topic.topicTitle, style: NewsPaperStyle.headline(context, headlineSize)),
            ],
          ),
        ),
      ],
    );
  }
}

/// AI 插圖，預設 4:3（畫出來是正方形，太扁會切掉主體），下面標「AI 示意圖」
/// （2026-10-31 沛沛決定用 AI 插畫，不用新聞照片）
class NewsIllustration extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  /// 小方圖太小，不另外標字（滑鼠移上去看得到）
  final bool showCaption;

  const NewsIllustration({super.key, required this.imageUrl, this.aspectRatio = 4 / 3, this.showCaption = true});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget image = AspectRatio(
      aspectRatio: aspectRatio,
      // 圖還在下載時先放淡灰底，不會看起來像一塊空白
      child: ColoredBox(
        color: colors.ink3.withValues(alpha: 0.12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          // 下載完淡入
          frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 300), child: child);
          },
          // 讀不到圖就只留淡灰底，不留破圖
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
    if (!showCaption) return Tooltip(message: 'AI 示意圖', child: image);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          image,
          const SizedBox(height: 2),
          Text('AI 示意圖', style: TextStyle(fontSize: 10, color: colors.ink3)),
        ],
      ),
    );
  }
}

/// 「讀更多」「另 N 家報導」這種點了在原地展開的小字
class _InlineToggle extends StatelessWidget {
  final String label;
  final bool isOpen;
  final VoidCallback onTap;

  const _InlineToggle({required this.label, required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.expand_more_rounded;
    if (isOpen) icon = Icons.expand_less_rounded;
    final Color color = context.appColors.acc;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

/// 展開後的其他報導：左邊一條主題色細線，每行一家媒體
class _OtherArticlesList extends StatelessWidget {
  final List<InsuranceNewsArticle> articles;

  const _OtherArticlesList({required this.articles});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: context.appColors.acc, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: articles.map((InsuranceNewsArticle article) => NewsArticleLine(article: article)).toList(),
      ),
    );
  }
}
