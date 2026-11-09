import '../../../widgets/walkthrough/walkthrough_step.dart';

// 人脈拓撲的操作示範（2026-11-08）：畫面全是王小明帳號的真實截圖。
// 示範用的家人陳小安是實際新增、截完圖再刪除的。
const String _folder = 'assets/images/walkthrough/network';
const String _graph = '$_folder/t01_graph.jpg';
const String _searchResult = '$_folder/t02_search.jpg';
const String _personCard = '$_folder/t03_card.jpg';
const String _manageDialog = '$_folder/t04_manage.jpg';
const String _relationFilled = '$_folder/t05_filled.jpg';
const String _relationAdded = '$_folder/t06_added.jpg';
const String _graphWithNewPerson = '$_folder/t07_graph_new.jpg';

/// 人脈拓撲的步驟
List<WalkthroughStep> buildNetworkWalkthrough() {
  final WalkthroughCamera relationCloseUp = walkthroughLook(455, 260, 1.8);

  return [
    WalkthroughStep(
      title: '找人：打姓氏就好',
      description: '在左上角打姓氏或名字，符合的人會一起亮起來，旁邊也會列出清單。',
      image: _graph,
      imageAfter: _searchResult,
      target: walkthroughAt(170, 61),
    ),
    WalkthroughStep(
      title: '點名字，看他的人脈',
      description: '點清單上的名字，畫面會移到這個人，只亮出和他有關的人。',
      image: _searchResult,
      imageAfter: _personCard,
      target: walkthroughAt(150, 133),
    ),
    WalkthroughStep(
      title: '線上寫著關係，箭頭是誰介紹誰',
      description: '箭頭從介紹人指向被介紹的人；同一對人的關係都寫在同一條線上。',
      image: _personCard,
      target: walkthroughAt(500, 268),
      action: WalkthroughAction.point,
      camera: relationCloseUp,
      cameraAfter: relationCloseUp,
      holdMilliseconds: 2200,
    ),
    WalkthroughStep(
      title: '想加人或改關係？按「管理關係」',
      description: '左上角的資訊卡可以直接打開這位客戶，或管理他的關係。',
      image: _personCard,
      imageAfter: _manageDialog,
      target: walkthroughAt(212, 177),
    ),
    WalkthroughStep(
      title: '打名字、選關係',
      description: '打現有客戶的名字，或打新名字直接建立；再選是他的什麼人，是他介紹的就打勾。',
      image: _manageDialog,
      imageAfter: _relationFilled,
      target: walkthroughAt(400, 235),
      holdMilliseconds: 1500,
    ),
    WalkthroughStep(
      title: '按「新增」',
      description: '新的關係馬上出現在上面的清單。',
      image: _relationFilled,
      imageAfter: _relationAdded,
      target: walkthroughAt(508, 330),
    ),
    WalkthroughStep(
      title: '關閉後，圖上就多了這個人',
      description: '畫面會自動移到新加的人，一眼看到他和誰有關係。',
      image: _relationAdded,
      imageAfter: _graphWithNewPerson,
      target: walkthroughAt(510, 414),
      holdMilliseconds: 2000,
    ),
  ];
}
