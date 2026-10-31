import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 一個新聞話題（同一件事，可能有好幾家媒體報導）
class InsuranceNewsTopic {
  final String id;
  final String topicTitle;
  final String category;
  final String? mainImageUrl;

  /// AI 整理的話題重點（報紙版「讀更多」看全文）
  final String aiSummary;

  /// AI 寫的一句短重點、關鍵數字（2026-10-31 起才有，舊資料是空字串）
  final String shortSummary;
  final String keyNumber;
  final String keyNumberLabel;
  final String? dailyTrend;
  final String? dailyOverview;
  final String publishDate;

  /// 真正抓到這個話題的時間（資料庫寫入時間）
  final DateTime? createdAt;
  final List<InsuranceNewsArticle> articles;

  InsuranceNewsTopic({
    required this.id,
    required this.topicTitle,
    required this.category,
    this.mainImageUrl,
    required this.aiSummary,
    this.shortSummary = '',
    this.keyNumber = '',
    this.keyNumberLabel = '',
    this.dailyTrend,
    this.dailyOverview,
    required this.publishDate,
    this.createdAt,
    required this.articles,
  });

  factory InsuranceNewsTopic.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawArticles = json['insurance_news_articles'] as List<dynamic>? ?? [];
    final List<InsuranceNewsArticle> articles = [];
    for (final dynamic rawArticle in rawArticles) {
      articles.add(InsuranceNewsArticle.fromJson(rawArticle as Map<String, dynamic>));
    }
    return InsuranceNewsTopic(
      id: json['id'] as String,
      topicTitle: json['topic_title'] as String? ?? '新聞頭條話題',
      category: json['category'] as String? ?? '保險焦點',
      mainImageUrl: json['main_image_url'] as String?,
      aiSummary: json['ai_summary'] as String? ?? '',
      shortSummary: (json['short_summary'] as String? ?? '').trim(),
      keyNumber: (json['key_number'] as String? ?? '').trim(),
      keyNumberLabel: (json['key_number_label'] as String? ?? '').trim(),
      dailyTrend: json['daily_trend'] as String?,
      dailyOverview: json['daily_overview'] as String?,
      publishDate: json['publish_date'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      articles: articles,
    );
  }

  /// 主要報導：有標記 is_primary 的那篇，沒有就用第一篇
  InsuranceNewsArticle? get primaryArticle {
    for (final InsuranceNewsArticle article in articles) {
      if (article.isPrimary) return article;
    }
    if (articles.isEmpty) return null;
    return articles.first;
  }

  /// 主要報導以外的其他報導
  List<InsuranceNewsArticle> get otherArticles {
    final InsuranceNewsArticle? primary = primaryArticle;
    return articles.where((InsuranceNewsArticle article) => article != primary).toList();
  }
}

/// 一家媒體的一篇報導
class InsuranceNewsArticle {
  final String id;
  final String topicId;
  final String title;
  final String sourceName;
  final String sourceUrl;

  /// 單篇重點；AI 沒寫或跟標題一樣時是空字串（2026-10-31 拿掉原本自動補的假摘要）
  final String articleSummary;
  final String? publishedAt;
  final bool isPrimary;

  InsuranceNewsArticle({
    required this.id,
    required this.topicId,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.articleSummary,
    this.publishedAt,
    required this.isPrimary,
  });

  factory InsuranceNewsArticle.fromJson(Map<String, dynamic> json) {
    final String title = json['title'] as String? ?? '新聞標題';
    String summary = (json['article_summary'] as String? ?? '').trim();
    if (summary == title) summary = '';
    return InsuranceNewsArticle(
      id: json['id'] as String? ?? '',
      topicId: json['topic_id'] as String? ?? '',
      title: title,
      sourceName: json['source_name'] as String? ?? '新聞來源',
      sourceUrl: json['source_url'] as String? ?? '',
      articleSummary: summary,
      publishedAt: json['published_at'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

/// 一份「今天的報紙」：所有話題＋今日大勢＋真正的更新時間
class InsuranceNewsEdition {
  final List<InsuranceNewsTopic> topics;

  /// 當天話題太少時，下面補「前一天焦點」（2026-10-31 沛沛決定）
  final List<InsuranceNewsTopic> previousTopics;

  const InsuranceNewsEdition(this.topics, {this.previousTopics = const []});

  /// 今日大勢一句話、完整總覽（每個話題都存同一份，取第一個有的）
  String get dailyTrend => _firstNonEmpty((InsuranceNewsTopic topic) => topic.dailyTrend);
  String get dailyOverview => _firstNonEmpty((InsuranceNewsTopic topic) => topic.dailyOverview);

  String _firstNonEmpty(String? Function(InsuranceNewsTopic topic) pick) {
    for (final InsuranceNewsTopic topic in topics) {
      final String text = pick(topic)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// 最近一次真正抓到新聞的時間（不再寫死 06:00）
  DateTime? get updatedAt {
    DateTime? latest;
    for (final InsuranceNewsTopic topic in topics) {
      final DateTime? createdAt = topic.createdAt;
      if (createdAt == null) continue;
      if (latest == null || createdAt.isAfter(latest)) latest = createdAt;
    }
    return latest?.toLocal();
  }

  int get articleCount {
    int count = 0;
    for (final InsuranceNewsTopic topic in topics) {
      count += topic.articles.length;
    }
    return count;
  }
}

/// 讀新聞頭條（從 insurance_news_tab.dart 搬出，2026-10-31）
class InsuranceNewsService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// 當天少於這麼多則話題，才補前一天焦點
  static const int _fewTopicsThreshold = 6;

  /// 前一天焦點最多幾則
  static const int _maxPreviousTopics = 6;

  /// 最新一天的報紙（2026-10-31 沛沛反映混到前一天的話題、出現 0 家報導）
  /// - 抓新聞一天兩次、同一天會累加（晨報＋夕報），所以收「和最新一則同一天」的全部話題
  /// - 沒有任何報導的話題不顯示；同標題只留一個
  /// - 當天少於 6 則時，另外帶前一天的話題當「前一天焦點」
  static Future<InsuranceNewsEdition> fetchLatestEdition() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('insurance_news_topics')
          .select('*, insurance_news_articles(*)')
          .order('created_at', ascending: false)
          .limit(40);
      final List<List<InsuranceNewsTopic>> days = _groupByDay(rows);
      if (days.isEmpty) return const InsuranceNewsEdition([]);
      final List<InsuranceNewsTopic> todayTopics = _cleanTopics(days.first);
      List<InsuranceNewsTopic> previousTopics = [];
      if (todayTopics.length < _fewTopicsThreshold && days.length > 1) {
        previousTopics = _cleanTopics(days[1]).take(_maxPreviousTopics).toList();
      }
      return InsuranceNewsEdition(todayTopics, previousTopics: previousTopics);
    } catch (error) {
      if (kDebugMode) print('讀取保險新聞失敗: $error');
      return const InsuranceNewsEdition([]);
    }
  }

  // 資料已依時間由新到舊排好：照 publish_date 分成一天一組，最新的一天在最前面
  static List<List<InsuranceNewsTopic>> _groupByDay(List<dynamic> rows) {
    final List<List<InsuranceNewsTopic>> days = [];
    String? currentDate;
    for (final dynamic row in rows) {
      final InsuranceNewsTopic topic = InsuranceNewsTopic.fromJson(row as Map<String, dynamic>);
      if (topic.publishDate != currentDate) {
        days.add([]);
        currentDate = topic.publishDate;
      }
      days.last.add(topic);
    }
    return days;
  }

  // 拿掉沒有任何報導的話題；同標題只留一個
  static List<InsuranceNewsTopic> _cleanTopics(List<InsuranceNewsTopic> topics) {
    final Map<String, InsuranceNewsTopic> topicByTitle = {};
    for (final InsuranceNewsTopic topic in topics) {
      if (topic.articles.isEmpty) continue;
      topicByTitle.putIfAbsent(topic.topicTitle.trim(), () => topic);
    }
    return topicByTitle.values.toList();
  }
}

/// 從 AI 重點挑字：只取前幾句、找關鍵數字（2026-10-31 沛沛反映字太多）
class NewsTextHelper {
  static final RegExp _sentenceEnd = RegExp(r'[。！？]');

  /// 只取前 [count] 句；本來就沒那麼多句就整段回傳
  static String firstSentences(String text, int count) {
    final String trimmed = text.trim();
    int found = 0;
    for (final RegExpMatch match in _sentenceEnd.allMatches(trimmed)) {
      found++;
      if (found == count) return trimmed.substring(0, match.end);
    }
    return trimmed;
  }

  // 數字後面接億、萬、%、倍才算（避開「2026 年」這種年份）
  static final RegExp _keyNumber = RegExp(r'(\d[\d,]*(?:\.\d+)?)\s*(億|萬|%|％|倍)');

  /// 內文裡第一個關鍵數字，例「8100萬」→「8,100 萬」；找不到回傳 null
  static String? keyNumber(String text) {
    final RegExpMatch? match = _keyNumber.firstMatch(text);
    if (match == null) return null;
    final String digits = match.group(1)!.replaceAll(',', '');
    final String unit = match.group(2)!.replaceAll('％', '%');
    final List<String> parts = digits.split('.');
    final String integerPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (Match _) => ',');
    String number = integerPart;
    if (parts.length > 1) number = '$integerPart.${parts[1]}';
    if (unit == '%') return '$number%';
    return '$number $unit';
  }
}
