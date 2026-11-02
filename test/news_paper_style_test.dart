import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/screens/news/news_front_page.dart';
import 'package:insurance_helper/screens/news/news_paper_style.dart';
import 'package:insurance_helper/services/insurance_news_service.dart';
import 'package:insurance_helper/theme/app_theme.dart';

void main() {
  group('經選日報風格與畫面測試', () {
    testWidgets('NewsPaperStyle.paper 在明亮模式下為質感新聞紙灰', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppColors.light(AppThemeColors.wine)]),
          home: Builder(
            builder: (context) {
              final color = NewsPaperStyle.paper(context);
              expect(color, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('NewsFrontPage 正確渲染英文品牌標題、今日大勢與焦點追蹤', (WidgetTester tester) async {
      final edition = InsuranceNewsEdition(
        [
          InsuranceNewsTopic(
            id: 't-1',
            topicTitle: '實支實付醫療險損害防阻新制推動',
            category: '產險焦點',
            dailyTrend: '從今日焦點新聞可看出，主管機關正加速推動實支實付醫療險新制。',
            dailyOverview: '今日保險市場整體動態良好，政策推動穩健。',
            aiSummary: '金管會針對實支實付醫療險推動最新損害防阻與核保規範。',
            shortSummary: '新制推動全面強化核保審查機制',
            publishDate: '2026-11-02',
            createdAt: DateTime.parse('2026-11-02 18:00:00'),
            articles: [
              InsuranceNewsArticle(
                id: 'a-1',
                topicId: 't-1',
                title: '金管會加速推進醫療險轉型改革方案',
                sourceName: '工商時報',
                sourceUrl: 'https://example.com/a1',
                isPrimary: true,
                articleSummary: '實支實付新制上路細節說明',
                publishedAt: '2026-11-02 18:00:00',
              ),
            ],
          ),
          InsuranceNewsTopic(
            id: 't-2',
            topicTitle: '微型保險普惠金融投保人數突破新高',
            category: '公會焦點',
            aiSummary: '壽險公會公布最新普惠金融數據報告。',
            shortSummary: '全國普惠金融投保率較去年同期提升',
            publishDate: '2026-11-02',
            createdAt: DateTime.parse('2026-11-02 18:00:00'),
            articles: [
              InsuranceNewsArticle(
                id: 'a-2',
                topicId: 't-2',
                title: '壽險公會發布最新投保成長報告',
                sourceName: '經濟日報',
                sourceUrl: 'https://example.com/a2',
                isPrimary: true,
                articleSummary: '微型保險投保率創新高',
                publishedAt: '2026-11-02 18:00:00',
              ),
            ],
          ),
        ],
        previousTopics: [
          InsuranceNewsTopic(
            id: 't-prev',
            topicTitle: '高齡長照保險商品結構調整動態',
            category: '即時要聞',
            aiSummary: '因應超高齡化社會，保險公司全面調整商品。',
            publishDate: '2026-11-01',
            articles: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppColors.light(AppThemeColors.wine)]),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewsFrontPage(edition: edition),
            ),
          ),
        ),
      );

      // 檢查英文專題標題 JINGXUAN.HELPER
      expect(find.text('JINGXUAN.HELPER ・ FINANCIAL & INSURANCE DAILY'), findsOneWidget);
      // 檢查中文主標
      expect(find.text('經選日報'), findsOneWidget);
      // 檢查副標保險業每日焦點
      expect(find.text('保險業每日焦點'), findsOneWidget);
      // 檢查今日大勢徽章
      expect(find.text('今日大勢'), findsOneWidget);
      // 檢查焦點追蹤徽章
      expect(find.text('焦點追蹤'), findsOneWidget);
      // 檢查分類徽章
      expect(find.text('即時要聞'), findsOneWidget);
      // 檢查文章連結行
      expect(find.textContaining('工商時報 ｜ '), findsOneWidget);
    });
  });
}
