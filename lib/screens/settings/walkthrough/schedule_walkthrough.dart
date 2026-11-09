import 'package:flutter/widgets.dart';

import '../../../widgets/walkthrough/walkthrough_step.dart';

// 今日行程的操作示範（2026-11-08 重做，沛沛定案）：畫面全是王小明帳號的真實截圖。
// 只教「不教可能不會用」的事：新增行程、語音排行程、路線規劃、議程清單；日、月檢視大家都會看，不教。
// 鏡頭平常看整個畫面，只有按鈕小、要看清楚時才放大（沛沛：放大太頻繁不適合）；有視窗的畫面不放大，才不會切到視窗邊緣的按鈕。
// 下面的座標是在 800×450 的截圖座標量出來的，直接照抄量到的數字比較好核對。
const String _folder = 'assets/images/walkthrough/schedule';
const String _monthEmptyDay = '$_folder/a01_month9.jpg';
const String _newEvent = '$_folder/a02_new.jpg';
const String _customerDropdown = '$_folder/a03_dropdown.jpg';
const String _customerSelected = '$_folder/a04_customer.jpg';
const String _locationFilled = '$_folder/a05_location.jpg';
const String _saveButtonVisible = '$_folder/a06_save.jpg';
const String _monthSaved = '$_folder/a07_saved.jpg';
const String _agenda = '$_folder/a09_agenda.jpg';
const String _monthBusyDay = '$_folder/b01_month5.jpg';
const String _routeDialog = '$_folder/b02_route.jpg';
const String _voiceRecording = '$_folder/v1_recording.jpg';
const String _voiceAnalyzing = '$_folder/v2_analyzing.jpg';
const String _voiceResult = '$_folder/v3_result.jpg';

const Offset Function(double, double) _at = walkthroughAt;
/// 今日行程的步驟
List<WalkthroughStep> buildScheduleWalkthrough() {
  final WalkthroughCamera micCloseUp = walkthroughLook(720, 390, 2);
  final WalkthroughCamera navigateCloseUp = walkthroughLook(460, 300, 1.9);

  return [
    // ── 新增行程 ──
    WalkthroughStep(
      title: '新增一個行程',
      description: '先在月曆上點要排的那一天，再按右上角「新增行程」。',
      image: _monthEmptyDay,
      imageAfter: _newEvent,
      target: _at(764, 90),
    ),
    WalkthroughStep(
      title: '選這次要見的客戶',
      description: '點「關聯客戶」打開名單。',
      image: _newEvent,
      imageAfter: _customerDropdown,
      target: _at(400, 89),
    ),
    WalkthroughStep(
      title: '點客戶的名字',
      description: '選好之後，行程標題會自動帶入「拜訪＋客戶名字」，想改也可以直接改。',
      image: _customerDropdown,
      imageAfter: _customerSelected,
      target: _at(310, 69),
    ),
    WalkthroughStep(
      title: '填上地點',
      description: '有填地點，之後才能用路線規劃排順路的路線。',
      image: _customerSelected,
      imageAfter: _locationFilled,
      target: _at(390, 234),
    ),
    WalkthroughStep(
      title: '按「新增行程」完成',
      description: '時間確認好按下去，月曆上那一天就多了這個行程。',
      image: _saveButtonVisible,
      imageAfter: _monthSaved,
      target: _at(500, 415),
    ),

    // ── 語音排行程 ──
    WalkthroughStep(
      title: '用說的排行程',
      description: '懶得打字？按右下角的麥克風。',
      image: _monthEmptyDay,
      imageAfter: _voiceRecording,
      target: _at(775, 426),
      camera: micCloseUp,
    ),
    WalkthroughStep(
      title: '說完按「完成」',
      description: '例如說「明天下午兩點拜訪陳志豪」，說完按「完成」。',
      image: _voiceRecording,
      imageAfter: _voiceAnalyzing,
      target: _at(538, 424),
      holdMilliseconds: 500,
    ),
    WalkthroughStep(
      title: 'AI 幫你填好了',
      description: '客戶、標題、日期、時間都填好了，看過沒問題就按「新增行程」。',
      image: _voiceAnalyzing,
      imageAfter: _voiceResult,
      target: _at(330, 126),
      action: WalkthroughAction.point,
      holdMilliseconds: 1800,
    ),

    // ── 路線規劃 ──
    WalkthroughStep(
      title: '一天要跑好幾個地方？',
      description: '點那一天，再按上方的「路線規劃」，有填地點的行程會依時間排好。',
      image: _monthBusyDay,
      imageAfter: _routeDialog,
      target: _at(566, 58),
    ),
    WalkthroughStep(
      title: '一鍵開 Google 地圖導航',
      description: '勾選要去的地點，按這裡就會在 Google 地圖排好多站路線。',
      image: _routeDialog,
      target: _at(460, 326),
      action: WalkthroughAction.point,
      camera: navigateCloseUp,
      cameraAfter: navigateCloseUp,
      holdMilliseconds: 1500,
    ),

    // ── 議程清單 ──
    WalkthroughStep(
      title: '想看接下來要去哪裡',
      description: '切到「議程清單」，之後的行程會依序列出來，每筆右邊可以導航或修改。',
      image: _monthBusyDay,
      imageAfter: _agenda,
      target: _at(728, 58),
      holdMilliseconds: 1800,
    ),
  ];
}
