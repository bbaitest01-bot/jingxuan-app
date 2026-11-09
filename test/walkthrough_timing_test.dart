import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/widgets/walkthrough/walkthrough_stage.dart';
import 'package:insurance_helper/widgets/walkthrough/walkthrough_step.dart';

void main() {
  group('操作示範每一步的時間（2026-11-08 沛沛：動作做完不要空等）', () {
    const WalkthroughStep pointOnly = WalkthroughStep(
      title: '只指給你看',
      description: '',
      image: 'a.jpg',
      target: Offset(0.5, 0.5),
      action: WalkthroughAction.point,
      holdMilliseconds: 500,
    );

    test('只指給你看：滑鼠到了再停一下就結束', () {
      expect(WalkthroughTiming.totalOf(pointOnly), WalkthroughTiming.moveEnd + 500);
    });

    test('點擊換畫面：畫面換完再停一下就結束', () {
      const WalkthroughStep click = WalkthroughStep(
        title: '點一下',
        description: '',
        image: 'a.jpg',
        imageAfter: 'b.jpg',
        target: Offset(0.5, 0.5),
        holdMilliseconds: 500,
      );
      expect(WalkthroughTiming.totalOf(click), WalkthroughTiming.imageChangeEnd + 500);
    });

    test('往下捲：捲到底再停一下就結束', () {
      const WalkthroughStep scrolling = WalkthroughStep(
        title: '往下捲',
        description: '',
        image: 'a.jpg',
        target: Offset(0.5, 0.5),
        action: WalkthroughAction.point,
        holdMilliseconds: 500,
        scroll: WalkthroughScroll(stripImage: 'b.jpg', stripAspectRatio: 0.75, region: Rect.fromLTRB(0.1, 0.1, 1, 1)),
      );
      expect(WalkthroughTiming.totalOf(scrolling), WalkthroughTiming.scrollEnd + 500);
    });

    test('操作後鏡頭要移動：才等鏡頭移完', () {
      const WalkthroughStep moveCamera = WalkthroughStep(
        title: '放大後回到全畫面',
        description: '',
        image: 'a.jpg',
        imageAfter: 'b.jpg',
        target: Offset(0.5, 0.5),
        camera: WalkthroughCamera(Offset(0.8, 0.8), 2),
        holdMilliseconds: 500,
      );
      expect(WalkthroughTiming.totalOf(moveCamera), WalkthroughTiming.cameraAfterEnd + 500);
    });
  });
}
