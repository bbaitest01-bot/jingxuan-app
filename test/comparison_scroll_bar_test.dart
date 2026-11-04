import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/theme/app_theme.dart';
import 'package:insurance_helper/widgets/comparison_scroll_bar.dart';

// 測試用的比較頁：columnCount 欄，每欄 300 寬（含間距）
Widget buildTestPage(ScrollController controller, int columnCount) {
  final List<Widget> columns = [];
  for (int index = 0; index < columnCount; index++) {
    columns.add(SizedBox(width: 300, height: 200, child: Text('商品 ${index + 1}')));
  }
  return MaterialApp(
    theme: AppTheme.light(AppThemeColors.deepSea),
    home: Scaffold(
      body: ComparisonScrollArea(
        controller: controller,
        columnCount: columnCount,
        columnStep: 300,
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Row(children: columns),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // 電腦寬度 1200：放得下 4 欄
  void useDesktopSize(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('放不下時顯示第幾款，按右箭頭移一款', (WidgetTester tester) async {
    useDesktopSize(tester, 1200);
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(buildTestPage(controller, 7));
    await tester.pumpAndSettle();

    expect(find.text('第 1–4 款／共 7 款', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('往右一款'));
    await tester.pumpAndSettle();
    expect(controller.offset, 300);
    expect(find.text('第 2–5 款／共 7 款', findRichText: true), findsOneWidget);
  });

  testWidgets('全部放得下時不顯示捲動列', (WidgetTester tester) async {
    useDesktopSize(tester, 1200);
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(buildTestPage(controller, 3));
    await tester.pumpAndSettle();

    expect(find.byTooltip('往右一款'), findsNothing);
  });

  testWidgets('手機寬度不顯示捲動列', (WidgetTester tester) async {
    useDesktopSize(tester, 400);
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(buildTestPage(controller, 7));
    await tester.pumpAndSettle();

    expect(find.byTooltip('往右一款'), findsNothing);
  });
}
