import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/insurance_news_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';

/// 經選日報的紙張與共用小零件（2026-10-31 沛沛選：報紙頭版＋報導熱度、紙張「灰 2」）
class NewsPaperStyle {
  /// 新聞紙灰：主題的灰字色淡淡疊在白底上（明亮模式約 #E7E8EA，深色模式跟著變暗）
  static Color paper(BuildContext context) {
    final AppColors colors = context.appColors;
    return Color.alphaBlend(colors.ink3.withValues(alpha: 0.16), colors.surface);
  }

  /// 報紙的分隔線顏色
  static Color rule(BuildContext context) => context.appColors.ink3.withValues(alpha: 0.55);

  /// 宋體標題
  static TextStyle headline(BuildContext context, double fontSize, {Color? color}) {
    return AppTextStyles.serif(fontSize: fontSize, color: color ?? context.appColors.ink).copyWith(height: 1.35);
  }

  /// 內文：深灰、行距大一點比較好讀
  static TextStyle body(BuildContext context, {double fontSize = 13.5}) {
    return TextStyle(fontSize: fontSize, height: 1.75, color: context.appColors.ink2);
  }
}

/// 報紙的雙線（頭版標題上下那種粗細兩條線）
class NewsDoubleRule extends StatelessWidget {
  const NewsDoubleRule({super.key});

  @override
  Widget build(BuildContext context) {
    final Color color = context.appColors.ink;
    return Column(
      children: [
        Container(height: 2, color: color),
        const SizedBox(height: 2),
        Container(height: 0.8, color: color),
      ],
    );
  }
}

/// 紙張：灰色底＋很淡的紙紋（細小網點）
class NewsPaperSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const NewsPaperSheet({super.key, required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NewsPaperStyle.paper(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: _PaperGrainPainter(context.appColors.ink.withValues(alpha: 0.05)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// 每 3 點畫一個很小的點，看起來像新聞紙的紋路；只畫一次（紙張不會動）
class _PaperGrainPainter extends CustomPainter {
  final Color dotColor;

  _PaperGrainPainter(this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()..color = dotColor;
    final List<Offset> dots = [];
    for (double y = 1.5; y < size.height; y += 3) {
      for (double x = 1.5; x < size.width; x += 3) {
        dots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, dots, dotPaint..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}

/// 報導熱度：五格，幾家報導就塗滿幾格（最多五格），後面寫「N 家報導」
class NewsHeatMeter extends StatelessWidget {
  final int articleCount;

  const NewsHeatMeter({super.key, required this.articleCount});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> cells = [];
    for (int index = 0; index < 5; index++) {
      Color cellColor = colors.ink3.withValues(alpha: 0.25);
      if (index < articleCount) cellColor = colors.acc;
      cells.add(Container(width: 10, height: 6, margin: const EdgeInsets.only(right: 2), color: cellColor));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...cells,
        const SizedBox(width: 6),
        Text('$articleCount 家報導', style: TextStyle(fontSize: 11, color: colors.ink3)),
      ],
    );
  }
}

/// 一行報導：「媒體｜標題 ↗」，點了開原文；電腦滑鼠移上去顯示單篇重點
class NewsArticleLine extends StatelessWidget {
  final InsuranceNewsArticle article;

  const NewsArticleLine({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget line = InkWell(
      onTap: () => openNewsArticle(context, article),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        // 媒體名接在標題前面一起換行，窄欄也不會被截掉（2026-10-31）
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${article.sourceName}｜', style: TextStyle(fontSize: 12, color: colors.ink3)),
              TextSpan(text: article.title, style: TextStyle(fontSize: 13, color: colors.ink)),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.north_east_rounded, size: 12, color: colors.ink3),
                ),
              ),
            ],
          ),
          style: const TextStyle(height: 1.5),
        ),
      ),
    );
    if (article.articleSummary.isEmpty) return line;
    return Tooltip(
      message: article.articleSummary,
      waitDuration: const Duration(milliseconds: 400),
      constraints: const BoxConstraints(maxWidth: 360),
      child: line,
    );
  }
}

/// 開新聞原文；網址無效時改用 Google 搜尋標題（沿用原本的備援做法）
Future<void> openNewsArticle(BuildContext context, InsuranceNewsArticle article) async {
  String url = article.sourceUrl.trim();
  final bool isGoogleNewsHome = url.isEmpty || RegExp(r'^https://news\.google\.com(/news)?/?$').hasMatch(url);
  if (isGoogleNewsHome) {
    url = 'https://www.google.com/search?q=${Uri.encodeComponent(article.title.trim())}';
  }
  try {
    final bool opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) CustomToast.show(context, '無法開啟這篇新聞的連結', ToastType.warning);
  } catch (error) {
    if (context.mounted) CustomToast.show(context, '無法開啟這篇新聞的連結', ToastType.warning);
  }
}
