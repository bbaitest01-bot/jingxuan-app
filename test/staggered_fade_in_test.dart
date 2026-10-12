import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/widgets/animations.dart';

// 取出 StaggeredFadeIn 裡淡入動畫目前的透明度
double currentOpacity(WidgetTester tester) {
  final FadeTransition fade = tester.widget<FadeTransition>(
    find.descendant(of: find.byType(StaggeredFadeIn), matching: find.byType(FadeTransition)),
  );
  return fade.opacity.value;
}

void main() {
  testWidgets('預設會播淡入動畫：一開始是透明的', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StaggeredFadeIn(index: 0, child: Text('客戶'))));
    expect(currentOpacity(tester), 0.0);
    await tester.pumpAndSettle();
    expect(currentOpacity(tester), 1.0);
  });

  testWidgets('animate: false 時一出現就完全顯示（顯示暫存客戶名單時用）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StaggeredFadeIn(index: 3, animate: false, child: Text('客戶'))));
    expect(currentOpacity(tester), 1.0);
  });
}
