import 'package:flutter/material.dart';

import '../services/insurance_news_service.dart';
import '../theme/app_theme.dart';
import 'news/news_front_page.dart';

/// 新聞頭條（網址 `/news`）：經選日報頭版
///
/// 2026-10-31 改版（沛沛選報紙頭版＋報導熱度、紙張灰 2）：原本 1,229 行拆成
/// 讀資料 `services/insurance_news_service.dart`、版面 `news/news_front_page.dart`、
/// 每則話題 `news/news_topic_story.dart`、紙張與小零件 `news/news_paper_style.dart`。
/// 原本的總覽、話題摘要、相關報導、單篇摘要四個彈出視窗都改成直接顯示或原地展開。
class InsuranceNewsTab extends StatefulWidget {
  const InsuranceNewsTab({super.key});

  @override
  State<InsuranceNewsTab> createState() => _InsuranceNewsTabState();
}

class _InsuranceNewsTabState extends State<InsuranceNewsTab> {
  bool _isLoading = true;
  InsuranceNewsEdition _edition = const InsuranceNewsEdition([]);

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final InsuranceNewsEdition edition = await InsuranceNewsService.fetchLatestEdition();
    if (!mounted) return;
    setState(() {
      _edition = edition;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Widget content;
    if (_isLoading) {
      content = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    } else if (_edition.topics.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(48),
        child: Center(child: Text('今天的新聞還沒整理好，稍後再來看看。', style: TextStyle(color: colors.ink3))),
      );
    } else {
      content = NewsFrontPage(edition: _edition);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: RefreshIndicator(
        onRefresh: _loadNews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: content),
          ),
        ),
      ),
    );
  }
}
