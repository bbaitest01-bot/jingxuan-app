import 'package:flutter/widgets.dart';

import '../../../widgets/walkthrough/walkthrough_step.dart';

// 客戶管理的操作示範（2026-11-08）：畫面全是王小明帳號的真實截圖。
// 示範用的客戶林美玲是實際新增、截完圖再刪除的；座標請見 walkthroughAt 的說明。
const String _folder = 'assets/images/walkthrough/customers';
const String _list = '$_folder/c01_list.jpg';
const String _newCustomer = '$_folder/c02_new.jpg';
const String _customerFilled = '$_folder/c03_filled.jpg';
const String _customerSaved = '$_folder/c04_saved.jpg';
const String _sideSheet = '$_folder/c05_sheet.jpg';
const String _coverageTab = '$_folder/c06_tab.jpg';
const String _addPolicy = '$_folder/c08_add.jpg';
const String _productFound = '$_folder/c09_found.jpg';
const String _policyAdded = '$_folder/c10_added.jpg';
const String _policyEdit = '$_folder/c11_edit.jpg';
const String _premiumFilled = '$_folder/c12_premium.jpg';
const String _policySaved = '$_folder/c13_saved.jpg';
const String _coverageGap = '$_folder/c15_gap.jpg';
const String _fullPage = '$_folder/c16_full.jpg';
const String _fullPageStrip = '$_folder/c17_strip.jpg';

/// 客戶管理的步驟
List<WalkthroughStep> buildCustomersWalkthrough() {
  final WalkthroughCamera gapCloseUp = walkthroughLook(655, 190, 1.9);

  return [
    // ── 新增客戶 ──
    WalkthroughStep(
      title: '新增一位客戶',
      description: '按右上角「新增客戶」。要一次加很多位，可以用旁邊的「批次匯入」。',
      image: _list,
      imageAfter: _newCustomer,
      target: walkthroughAt(753, 61),
    ),
    WalkthroughStep(
      title: '填上基本資料',
      description: '只有名字是一定要填的，其他之後再補也可以。',
      image: _newCustomer,
      imageAfter: _customerFilled,
      target: walkthroughAt(400, 105),
    ),
    WalkthroughStep(
      title: '按「儲存」',
      description: '客戶卡片會出現在清單最前面。',
      image: _customerFilled,
      imageAfter: _customerSaved,
      target: walkthroughAt(492, 415),
    ),

    // ── 看客戶資料 ──
    WalkthroughStep(
      title: '點卡片看這位客戶',
      description: '點一下卡片，右邊會打開他的完整資料。',
      image: _customerSaved,
      imageAfter: _sideSheet,
      target: walkthroughAt(245, 160),
    ),

    // ── 新增保單 ──
    WalkthroughStep(
      title: '切到「保單健檢與缺口」',
      description: '客戶買過的保單和保障都在這一頁。',
      image: _sideSheet,
      imageAfter: _coverageTab,
      target: walkthroughAt(658, 56),
    ),
    WalkthroughStep(
      title: '加入他的保單',
      description: '按「搜尋商品加入」；也可以按旁邊的「掃描保單」拍照帶入。',
      image: _coverageTab,
      imageAfter: _addPolicy,
      target: walkthroughAt(713, 391),
    ),
    WalkthroughStep(
      title: '打商品名字找保單',
      description: '上方可以先選保單狀態，例如有效、減額繳清、停效。',
      image: _addPolicy,
      imageAfter: _productFound,
      target: walkthroughAt(650, 317),
    ),
    WalkthroughStep(
      title: '按「加入」',
      description: '找到商品後按右邊的「加入」，保單就列進來了。',
      image: _productFound,
      imageAfter: _policyAdded,
      target: walkthroughAt(759, 353),
    ),
    WalkthroughStep(
      title: '補上保單資料',
      description: '按「編輯」，可以填要保人、被保險人、受益人、生效日和保費。',
      image: _policyAdded,
      imageAfter: _policyEdit,
      target: walkthroughAt(749, 369),
    ),
    WalkthroughStep(
      title: '選繳別、填每期保費',
      description: '填好之後，下面會自動算出一年要繳多少。',
      image: _policyEdit,
      imageAfter: _premiumFilled,
      target: walkthroughAt(306, 282),
      holdMilliseconds: 1500,
    ),
    WalkthroughStep(
      title: '按「儲存」',
      description: '一年總保費會顯示在保單清單上方。',
      image: _premiumFilled,
      imageAfter: _policySaved,
      target: walkthroughAt(497, 377),
    ),

    // ── 看保障缺口 ──
    WalkthroughStep(
      title: '一眼看出保障缺口',
      description: '按「設定目標」填想要的保額，右邊就會算出還差多少，談加保更有根據。',
      image: _coverageGap,
      target: walkthroughAt(756, 149),
      action: WalkthroughAction.point,
      camera: gapCloseUp,
      cameraAfter: gapCloseUp,
      holdMilliseconds: 2200,
    ),

    // ── 全螢幕看完整頁面（沛沛 2026-11-08：圖示藏在右上角，沒人教不會知道）──
    WalkthroughStep(
      title: '想看得更完整？放大成整頁',
      description: '按右上角這個斜箭頭圖示，客戶的所有資料會打開成一整頁。',
      image: _coverageGap,
      imageAfter: _fullPage,
      target: walkthroughAt(744, 18),
      camera: walkthroughLook(680, 40, 2.2),
    ),
    WalkthroughStep(
      title: '往下滑，資料都在這一頁',
      description: '保單健檢、有效和已失效的保單、拜訪紀錄都排在一起，往下滑就看得到。',
      image: _fullPage,
      target: walkthroughAt(450, 300),
      action: WalkthroughAction.point,
      scroll: const WalkthroughScroll(
        stripImage: _fullPageStrip,
        // 長圖是 2540×3354；內容區是畫面扣掉左側選單（400）和頂列（146），整個畫面 2940×1654
        stripAspectRatio: 2540 / 3354,
        region: Rect.fromLTRB(400 / 2940, 146 / 1654, 1, 1),
      ),
      holdMilliseconds: 1500,
    ),
  ];
}
