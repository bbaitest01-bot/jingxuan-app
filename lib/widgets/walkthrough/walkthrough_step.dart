import 'package:flutter/widgets.dart';

/// 鏡頭要看畫面的哪裡：[center] 是中心點（0～1 的比例），[zoom] 是放大倍率（1＝看整個畫面）
class WalkthroughCamera {
  final Offset center;
  final double zoom;

  const WalkthroughCamera(this.center, this.zoom);

  /// 看整個畫面
  static const WalkthroughCamera full = WalkthroughCamera(Offset(0.5, 0.5), 1);

  /// 兩個鏡頭是不是看同一個地方
  bool isSameAs(WalkthroughCamera other) => center == other.center && zoom == other.zoom;
}

/// 頁面往下捲的示範：[stripImage] 是整頁內容的長圖，在畫面的 [region] 範圍裡由上往下捲
/// （左側選單、頂列留在原本的截圖上不動，看起來就像真的在捲頁面）
class WalkthroughScroll {
  final String stripImage;

  /// 長圖的寬 ÷ 高
  final double stripAspectRatio;

  /// 內容區在畫面上的範圍（0～1 的比例）
  final Rect region;

  const WalkthroughScroll({required this.stripImage, required this.stripAspectRatio, required this.region});
}

/// 把截圖座標換算成 0～1 的比例。截圖都是 1470×827 的畫面，用 800×450 的座標量位置
Offset walkthroughAt(double x, double y) => Offset(x / 800, y / 450);

/// 鏡頭看截圖座標 (x, y) 附近，放大 [zoom] 倍
WalkthroughCamera walkthroughLook(double x, double y, double zoom) => WalkthroughCamera(walkthroughAt(x, y), zoom);

/// 這一步滑鼠要做什麼：點一下（有波紋）或只是指給你看
enum WalkthroughAction { click, point }

/// 操作示範的一步：畫面都是真實 App 的截圖，點的位置是從截圖量出來的比例
class WalkthroughStep {
  final String title;
  final String description;

  /// 這一步一開始的畫面
  final String image;

  /// 操作之後變成的畫面；null＝畫面不變
  final String? imageAfter;

  /// 滑鼠要去的位置（0～1 的比例）
  final Offset target;

  final WalkthroughAction action;

  /// 操作時鏡頭看哪裡
  final WalkthroughCamera camera;

  /// 操作之後鏡頭看哪裡
  final WalkthroughCamera cameraAfter;

  /// 動作都做完之後再停留多久（毫秒）；說明文字一開始就顯示了，這裡只留一點看結果的時間
  final int holdMilliseconds;

  /// 這一步要不要示範往下捲；null＝不捲
  final WalkthroughScroll? scroll;

  const WalkthroughStep({
    required this.title,
    required this.description,
    required this.image,
    this.imageAfter,
    required this.target,
    this.action = WalkthroughAction.click,
    this.camera = WalkthroughCamera.full,
    this.cameraAfter = WalkthroughCamera.full,
    this.holdMilliseconds = 1000,
    this.scroll,
  });

  /// 這一步結束時畫面上的圖
  String get endImage => imageAfter ?? image;
}
