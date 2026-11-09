import 'package:flutter/widgets.dart';

import '../../../widgets/walkthrough/walkthrough_step.dart';

// 數據戰情的操作示範（2026-11-09 小陳）：畫面全是王小明帳號的真實截圖。
// 這個功能只是看資料，比較、試算都不會存任何東西。
// 這台電腦（Windows）截到的畫布是 1838×1034，轉圖時一起放大成 2000×1125。
const String _folder = 'assets/images/walkthrough/insights';
const String _overview = '$_folder/d01_overview.jpg';
const String _medicalFiltered = '$_folder/d02_medical.jpg';
const String _oneSelected = '$_folder/d03_one.jpg';
const String _twoSelected = '$_folder/d04_two.jpg';
const String _comparePage = '$_folder/d05_compare.jpg';
const String _dailyAmountFilled = '$_folder/d06_daily.jpg';
const String _compareBottom = '$_folder/d07_bottom.jpg';
const String _clauseDialog = '$_folder/d08_clause.jpg';
const String _comparePageStrip = '$_folder/d09_strip.jpg';

/// 數據戰情的步驟
List<WalkthroughStep> buildInsightsWalkthrough() {
  // 最上面的客戶概況四張卡
  final WalkthroughCamera customerSummaryCloseUp = walkthroughLook(420, 110, 1.4);
  // 比較頁左上角的情境試算
  final WalkthroughCamera scenarioCloseUp = walkthroughLook(260, 95, 1.6);
  // 第二款商品填了日額之後算出來的金額
  final WalkthroughCamera dailyResultCloseUp = walkthroughLook(260, 280, 1.6);

  return [
    // ── 客戶概況 ──
    WalkthroughStep(
      title: '先看客戶概況',
      description: '保戶、跟進中、未開發各有幾位；點進去會直接列出那群客戶。',
      image: _overview,
      target: walkthroughAt(200, 110),
      action: WalkthroughAction.point,
      camera: customerSummaryCloseUp,
      cameraAfter: customerSummaryCloseUp,
      holdMilliseconds: 2200,
    ),

    // ── 挑商品比較 ──
    WalkthroughStep(
      title: '點分類，篩出想看的商品',
      description: '也可以在搜尋框打商品名稱、代碼或保險公司。',
      image: _overview,
      imageAfter: _medicalFiltered,
      target: walkthroughAt(186, 268),
    ),
    WalkthroughStep(
      title: '按右上角的圓圈，勾選商品',
      description: '勾好的商品會出現在下方的比較列。',
      image: _medicalFiltered,
      imageAfter: _oneSelected,
      target: walkthroughAt(322, 308),
    ),
    WalkthroughStep(
      title: '再勾一款，最多 8 款',
      description: '想比幾款就勾幾款。',
      image: _oneSelected,
      imageAfter: _twoSelected,
      target: walkthroughAt(548, 308),
    ),
    WalkthroughStep(
      title: '按「開始比較」',
      description: '勾的商品會並排在同一頁；右上角可以切成「只看差異」。',
      image: _twoSelected,
      imageAfter: _comparePage,
      target: walkthroughAt(746, 424),
      holdMilliseconds: 1500,
    ),

    // ── 情境試算 ──
    WalkthroughStep(
      title: '情境試算：如果住院，各拿多少？',
      description: '上面選情境（住院、身故、癌症…），填天數和花費，每款都會算出大約金額。',
      image: _comparePage,
      target: walkthroughAt(37, 85),
      action: WalkthroughAction.point,
      camera: scenarioCloseUp,
      cameraAfter: scenarioCloseUp,
      holdMilliseconds: 2500,
    ),
    WalkthroughStep(
      title: '有的商品要先填日額或保額',
      description: '填了才算得出來，例如日額填 2000，下面馬上算出大約可以拿多少。',
      image: _comparePage,
      imageAfter: _dailyAmountFilled,
      target: walkthroughAt(258, 254),
      cameraAfter: dailyResultCloseUp,
      holdMilliseconds: 2000,
    ),

    // ── 給付項目與條款 ──
    WalkthroughStep(
      title: '往下捲，看給付項目',
      description: '每一項怎麼賠都列在這裡，填了日額的商品還會直接算出金額。',
      image: _dailyAmountFilled,
      target: walkthroughAt(650, 300),
      action: WalkthroughAction.point,
      scroll: const WalkthroughScroll(
        stripImage: _comparePageStrip,
        // 長圖是 2000×3217；內容區是畫面扣掉頂列（70），整個畫面 1838×1034
        stripAspectRatio: 2000 / 3217,
        region: Rect.fromLTRB(0, 70 / 1034, 1, 1),
      ),
      holdMilliseconds: 1000,
    ),
    WalkthroughStep(
      title: '點旁邊的小圖示看條款原文',
      description: '想確認細節就看原文；每款下面還有「加到客戶」和「官方條款 PDF」。',
      image: _compareBottom,
      imageAfter: _clauseDialog,
      target: walkthroughAt(330, 170),
      holdMilliseconds: 2500,
    ),
  ];
}
