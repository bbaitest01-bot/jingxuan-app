import '../../../widgets/walkthrough/walkthrough_step.dart';

// 個人帳號的操作示範（2026-11-09 小陳）：畫面全是王小明帳號的真實截圖。
// 換模板只是示範，沒有按「儲存變更」，截完重新整理就回到原本的名片。
// 這台電腦（Windows）截到的畫布是 1838×1034，轉圖時一起放大成 2000×1125。
const String _folder = 'assets/images/walkthrough/profile';
const String _cardFront = '$_folder/p01_front.jpg';
const String _cardBack = '$_folder/p02_back.jpg';
const String _drawerHovered = '$_folder/p03_drawer.jpg';
const String _templatePicked = '$_folder/p04_picked.jpg';
const String _downloadPreview = '$_folder/p05_download.jpg';

/// 個人帳號的步驟
List<WalkthroughStep> buildProfileWalkthrough() {
  // 模板抽屜在左下角，卡片很小，放大才看得出來一張張浮起來
  final WalkthroughCamera drawerCloseUp = walkthroughLook(290, 330, 1.8);

  return [
    WalkthroughStep(
      title: '點一下名片，翻到背面',
      description: '背面是你的服務理念和專長；再點一下就翻回正面。滑鼠在名片上移動，名片還會跟著傾斜反光。',
      image: _cardFront,
      imageAfter: _cardBack,
      target: walkthroughAt(288, 175),
      holdMilliseconds: 1800,
    ),
    WalkthroughStep(
      title: '下面是模板抽屜，滑過去挑',
      description: '滑鼠滑過去，卡片會一張張浮起來，每張都是用你的資料做的預覽。',
      image: _cardFront,
      imageAfter: _drawerHovered,
      target: walkthroughAt(300, 372),
      action: WalkthroughAction.point,
      camera: drawerCloseUp,
      cameraAfter: drawerCloseUp,
      holdMilliseconds: 1500,
    ),
    WalkthroughStep(
      title: '點一張，名片馬上換樣子',
      description: '點喜歡的模板，上面的名片立刻換掉；旁邊的小圓點可以換顏色。',
      image: _drawerHovered,
      imageAfter: _templatePicked,
      target: walkthroughAt(318, 356),
      camera: drawerCloseUp,
      holdMilliseconds: 1500,
    ),
    WalkthroughStep(
      title: '改好了，記得按「儲存變更」',
      description: '右邊的資料改了，名片會馬上跟著變；但要按右上角「儲存變更」才會存起來。',
      image: _templatePicked,
      target: walkthroughAt(744, 67),
      action: WalkthroughAction.point,
      holdMilliseconds: 1800,
    ),
    WalkthroughStep(
      title: '按「下載名片」',
      description: '正面、背面會放在同一張圖，確認後就能直接傳給客戶。',
      image: _templatePicked,
      imageAfter: _downloadPreview,
      target: walkthroughAt(288, 286),
      holdMilliseconds: 1800,
    ),
  ];
}
