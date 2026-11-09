import '../../../widgets/walkthrough/walkthrough_step.dart';

// 拜訪紀錄的操作示範（2026-11-08）：畫面全是真實截圖，從錄音到連結客戶是同一篇紀錄；
// 錄音那幾張是沛沛在自己的瀏覽器錄的（內建瀏覽器不能用麥克風）。
const String _folder = 'assets/images/walkthrough/visit_records';
const String _list = '$_folder/r01_list.jpg';
const String _recordReady = '$_folder/v1_ready.jpg';
const String _recording = '$_folder/v2_recording.jpg';
const String _organizing = '$_folder/v3_organizing.jpg';
const String _organized = '$_folder/v4_done.jpg';
const String _recordDetail = '$_folder/r03_detail.jpg';
const String _customerPicker = '$_folder/r04_picker.jpg';
const String _customerFound = '$_folder/r05_found.jpg';
const String _customerLinked = '$_folder/r06_linked.jpg';

/// 拜訪紀錄的步驟
List<WalkthroughStep> buildVisitRecordsWalkthrough() {
  return [
    WalkthroughStep(
      title: '拜訪完，按「錄音新增」',
      description: '不用打字，用講的就好。',
      image: _list,
      imageAfter: _recordReady,
      target: walkthroughAt(243, 61),
    ),
    WalkthroughStep(
      title: '按「錄音」開始說',
      description: '把今天聊到的重點講出來，最長可以錄 10 分鐘。',
      image: _recordReady,
      imageAfter: _recording,
      target: walkthroughAt(514, 230),
    ),
    WalkthroughStep(
      title: '說完按「完成」',
      description: '錄音會自動轉成文字，建立一篇拜訪紀錄。',
      image: _recording,
      imageAfter: _organizing,
      target: walkthroughAt(513, 231),
    ),
    WalkthroughStep(
      title: 'AI 自動整理',
      description: '通常幾秒到一分鐘，可以先離開這一頁，整理好鈴鐺會通知你。',
      image: _organizing,
      target: walkthroughAt(316, 172),
      action: WalkthroughAction.point,
      holdMilliseconds: 1800,
    ),
    WalkthroughStep(
      title: '左邊是原文，右邊是整理好的',
      description: '原始轉錄不會被改；AI 會修正錯字（像「十之十父」改成「實支實付」），放在右邊。',
      image: _organized,
      target: walkthroughAt(600, 290),
      action: WalkthroughAction.point,
      holdMilliseconds: 1800,
    ),
    WalkthroughStep(
      title: '把紀錄連到客戶',
      description: '按「選擇客戶」，這篇紀錄就會出現在客戶的資料裡。',
      image: _recordDetail,
      imageAfter: _customerPicker,
      target: walkthroughAt(720, 136),
    ),
    WalkthroughStep(
      title: '打名字找客戶',
      description: '可以用姓名、暱稱或電話搜尋。',
      image: _customerPicker,
      imageAfter: _customerFound,
      target: walkthroughAt(400, 120),
    ),
    WalkthroughStep(
      title: '點客戶的名字',
      description: '選好之後，上方會顯示連結的客戶。',
      image: _customerFound,
      imageAfter: _customerLinked,
      target: walkthroughAt(340, 157),
    ),
    WalkthroughStep(
      title: '想改就直接改，改完按「儲存」',
      description: '右邊的內容可以自己修改，標題也可以換成好認的名字。',
      image: _customerLinked,
      target: walkthroughAt(730, 61),
      action: WalkthroughAction.point,
      holdMilliseconds: 1800,
    ),
  ];
}
