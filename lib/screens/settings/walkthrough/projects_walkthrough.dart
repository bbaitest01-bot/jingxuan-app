import '../../../widgets/walkthrough/walkthrough_step.dart';

// 專案拜訪的操作示範（2026-11-09 小陳）：畫面全是王小明帳號的真實截圖。
// 示範專案「回診關懷」和鄭雅文的拜訪結果是實際建立、截完圖再用 App 刪除的。
// 這台電腦（Windows）截到的畫布是 1838×1034，轉圖時一起放大成 2000×1125。
const String _folder = 'assets/images/walkthrough/projects';
const String _overview = '$_folder/j01_overview.jpg';
const String _newProject = '$_folder/j02_new.jpg';
const String _projectFilled = '$_folder/j03_filled.jpg';
const String _membersPicked = '$_folder/j04_picked.jpg';
const String _projectReady = '$_folder/j05_ready.jpg';
const String _projectSaved = '$_folder/j06_saved.jpg';
const String _projectCards = '$_folder/j07_cards.jpg';
const String _recordVisit = '$_folder/j08_record.jpg';
const String _recordFilled = '$_folder/j09_filled.jpg';
const String _visitRecorded = '$_folder/j10_recorded.jpg';
const String _chart = '$_folder/j11_chart.jpg';
const String _pendingTab = '$_folder/j12_pending.jpg';

/// 專案拜訪的步驟
List<WalkthroughStep> buildProjectsWalkthrough() {
  // 新專案卡片在右下角，放大才看得清進度和「還有誰沒拜訪」
  final WalkthroughCamera newCardCloseUp = walkthroughLook(620, 395, 1.8);
  // 成效圖左半邊（這個月前幾天的線）
  final WalkthroughCamera chartCloseUp = walkthroughLook(240, 230, 1.8);

  return [
    // ── 建立專案 ──
    WalkthroughStep(
      title: '按「建立專案」',
      description: '想集中拜訪一群客戶（例如年底保單健檢），就開一個專案。',
      image: _overview,
      imageAfter: _newProject,
      target: walkthroughAt(692, 57),
    ),
    WalkthroughStep(
      title: '取名字、設期間和目標',
      description: '可以每月重複，也可以設固定期間；目標次數是這一期要拜訪幾次。',
      image: _newProject,
      imageAfter: _projectFilled,
      target: walkthroughAt(400, 130),
      holdMilliseconds: 1800,
    ),
    WalkthroughStep(
      title: '按「選擇名單」',
      description: '勾要拜訪的客戶。名單可以不選，不選就是任何客戶都算。',
      image: _projectFilled,
      imageAfter: _membersPicked,
      target: walkthroughAt(493, 304),
      holdMilliseconds: 1500,
    ),
    WalkthroughStep(
      title: '勾好按「確定」',
      description: '選了誰會列在視窗下方。',
      image: _membersPicked,
      imageAfter: _projectReady,
      target: walkthroughAt(497, 357),
    ),
    WalkthroughStep(
      title: '按「儲存」，專案卡片就出現了',
      description: '卡片上有這一期的進度，還列出名單上誰還沒拜訪。',
      image: _projectReady,
      imageAfter: _projectSaved,
      target: walkthroughAt(508, 344),
      cameraAfter: newCardCloseUp,
      holdMilliseconds: 2000,
    ),

    // ── 記錄拜訪 ──
    WalkthroughStep(
      title: '拜訪完，在卡片上按「記錄拜訪」',
      description: '從卡片按，專案會自動帶好，不用再選。',
      image: _projectCards,
      imageAfter: _recordVisit,
      target: walkthroughAt(498, 286),
    ),
    WalkthroughStep(
      title: '選客戶和結果，按「儲存」',
      description: '✔ 有意願、△ 考慮中、✖ 沒意願三選一，可以加一句備註。存好進度馬上加一。',
      image: _recordFilled,
      imageAfter: _visitRecorded,
      target: walkthroughAt(508, 350),
      cameraAfter: newCardCloseUp,
      holdMilliseconds: 2000,
    ),

    // ── 看成效、不漏記 ──
    WalkthroughStep(
      title: '上面的圖看成效',
      description: '每天各種結果有幾次，剛記的那筆就是最右邊往上的綠線；也可以切成「按專案」看。',
      image: _chart,
      target: walkthroughAt(318, 268),
      action: WalkthroughAction.point,
      camera: chartCloseUp,
      cameraAfter: chartCloseUp,
      holdMilliseconds: 2200,
    ),
    WalkthroughStep(
      title: '「待記錄」：排過行程還沒寫結果的',
      description: '今日行程排過的拜訪，還沒記錄結果的都列在這裡，按「記錄結果」就能補，不會漏掉。',
      image: _chart,
      imageAfter: _pendingTab,
      target: walkthroughAt(171, 84),
      holdMilliseconds: 2000,
    ),
  ];
}
