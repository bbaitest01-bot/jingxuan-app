import 'package:flutter/widgets.dart';

import '../../../widgets/walkthrough/walkthrough_step.dart';

// 新聞頭條的操作示範（2026-11-09 小陳）：畫面全是王小明帳號在 11/09 的真實截圖。
// 新聞內容每天不同，教學顯示的是截圖那天的新聞；座標請見 walkthroughAt 的說明。
// 這台電腦（Windows）截到的畫布是 1838×1034，轉圖時一起放大成 2000×1125。
const String _folder = 'assets/images/walkthrough/news';
const String _frontPage = '$_folder/n01_front.jpg';
const String _articleHovered = '$_folder/n02_hover.jpg';
const String _fullPageStrip = '$_folder/n03_strip.jpg';

/// 新聞頭條的步驟
List<WalkthroughStep> buildNewsWalkthrough() {
  // 報導熱度的格子很小，放大才看得清楚
  final WalkthroughCamera heatMeterCloseUp = walkthroughLook(610, 250, 2.0);
  // 滑鼠移上去跳出的摘要
  final WalkthroughCamera summaryCloseUp = walkthroughLook(630, 330, 1.6);

  return [
    WalkthroughStep(
      title: '先看左上角的「今日大勢」',
      description: '一句話告訴你今天保險業最重要的事，下面是完整總覽。',
      image: _frontPage,
      target: walkthroughAt(300, 170),
      action: WalkthroughAction.point,
      holdMilliseconds: 2000,
    ),
    WalkthroughStep(
      title: '格子越滿，越多家在報',
      description: '幾家媒體報導這個話題，就塗滿幾格，一眼看出哪則新聞最熱門。',
      image: _frontPage,
      target: walkthroughAt(575, 237),
      action: WalkthroughAction.point,
      camera: heatMeterCloseUp,
      cameraAfter: heatMeterCloseUp,
      holdMilliseconds: 2000,
    ),
    WalkthroughStep(
      title: '滑鼠移到報導上，先看重點',
      description: '停一下就會跳出這篇的摘要；想看全文，點一下就會開原文。',
      image: _frontPage,
      imageAfter: _articleHovered,
      target: walkthroughAt(640, 323),
      action: WalkthroughAction.point,
      camera: summaryCloseUp,
      cameraAfter: summaryCloseUp,
      holdMilliseconds: 2500,
    ),
    WalkthroughStep(
      title: '往下捲，還有其他話題',
      description: '其他新聞分成幾欄往下排；最下面的「焦點追蹤」是之前的重要話題後續。',
      image: _frontPage,
      target: walkthroughAt(450, 300),
      action: WalkthroughAction.point,
      scroll: const WalkthroughScroll(
        stripImage: _fullPageStrip,
        // 長圖是 1728×2514；內容區是畫面扣掉左側選單（250）和頂列（91），整個畫面 1838×1034
        stripAspectRatio: 1728 / 2514,
        region: Rect.fromLTRB(250 / 1838, 91 / 1034, 1, 1),
      ),
      holdMilliseconds: 1500,
    ),
  ];
}
