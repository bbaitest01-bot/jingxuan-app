import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/saved_comparison.dart';
import 'package:insurance_helper/screens/customers/customer_card.dart';
import 'package:insurance_helper/services/saved_comparison_service.dart';
import 'package:insurance_helper/services/scenario/claim_scenario.dart';
import 'package:insurance_helper/theme/app_theme.dart';
import 'package:insurance_helper/widgets/saved_comparison/saved_comparison_menu.dart';

SavedComparison buildComparison(String id, String name) {
  return SavedComparison(
    id: id,
    customerId: 'customer-1',
    name: name,
    scenario: const ClaimScenarioInput(),
    items: const [SavedComparisonItem(productId: 'p1'), SavedComparisonItem(productId: 'p2')],
    updatedAt: DateTime(2026, 11, 9, 12),
  );
}

class MenuCallLog {
  SavedComparison? opened;
  String? renamedId;
  String? newName;
  String? deletedId;
}

Future<void> pumpMenu(WidgetTester tester, MenuCallLog log, {int comparisonCount = 2}) async {
  final List<SavedComparison> comparisons = [];
  for (int index = 1; index <= comparisonCount; index++) {
    comparisons.add(buildComparison('c$index', '醫療$index'));
  }
  SavedComparisonService.instance.countByCustomer.value = {'customer-1': comparisonCount};
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(AppThemeColors.deepSea),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SavedComparisonMenuButton(
          customerId: 'customer-1',
          customerName: '王大明',
          fetchComparisons: (String customerId) async => comparisons,
          openComparison: (BuildContext context, SavedComparison comparison) async => log.opened = comparison,
          renameComparison: (String comparisonId, String newName) async {
            log.renamedId = comparisonId;
            log.newName = newName;
          },
          deleteComparison: (String comparisonId) async => log.deletedId = comparisonId,
        ),
      ),
    ),
  ));
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.textContaining('比較清單'));
  await tester.pumpAndSettle();
}

Future<void> showRowActions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('改名或刪除').first);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => SavedComparisonService.instance.countByCustomer.value = const {});

  testWidgets('沒存過比較就不顯示按鈕', (WidgetTester tester) async {
    await pumpMenu(tester, MenuCallLog(), comparisonCount: 0);
    expect(find.textContaining('比較清單'), findsNothing);
  });

  testWidgets('點開才列出比較，顯示款數與日期，按鈕大小不變', (WidgetTester tester) async {
    await pumpMenu(tester, MenuCallLog());
    expect(find.text('比較清單 2'), findsOneWidget);
    expect(find.text('醫療1'), findsNothing);
    final Size sizeBeforeOpen = tester.getSize(find.byType(SavedComparisonMenuButton));

    await openMenu(tester);

    expect(find.text('醫療1'), findsOneWidget);
    expect(find.text('醫療2'), findsOneWidget);
    expect(find.text('2 款・11/09 存'), findsNWidgets(2));
    expect(tester.getSize(find.byType(SavedComparisonMenuButton)), sizeBeforeOpen);
  });

  testWidgets('點選單外面會收起來', (WidgetTester tester) async {
    await pumpMenu(tester, MenuCallLog());
    await openMenu(tester);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.text('醫療1'), findsNothing);
  });

  testWidgets('筆數多時選單高度有上限，可以捲動', (WidgetTester tester) async {
    await pumpMenu(tester, MenuCallLog(), comparisonCount: 12);
    await openMenu(tester);
    expect(tester.getSize(find.byType(SingleChildScrollView).last).height, lessThanOrEqualTo(296));
  });

  testWidgets('點名稱打開那一筆', (WidgetTester tester) async {
    final MenuCallLog log = MenuCallLog();
    await pumpMenu(tester, log);
    await openMenu(tester);
    await tester.tap(find.text('醫療2'));
    await tester.pumpAndSettle();
    expect(log.opened?.id, 'c2');
  });

  testWidgets('改名：帶入舊名稱，存新名稱', (WidgetTester tester) async {
    final MenuCallLog log = MenuCallLog();
    await pumpMenu(tester, log);
    await openMenu(tester);
    await showRowActions(tester);
    await tester.tap(find.text('改名'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '醫療1');

    await tester.enterText(find.byType(TextField), '住院比較');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(log.renamedId, 'c1');
    expect(log.newName, '住院比較');
  });

  testWidgets('刪除要先確認，按取消不刪', (WidgetTester tester) async {
    final MenuCallLog log = MenuCallLog();
    await pumpMenu(tester, log);
    await openMenu(tester);
    await showRowActions(tester);
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(find.text('「醫療1」刪除後無法復原。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(log.deletedId, isNull);

    await openMenu(tester);
    await showRowActions(tester);
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(log.deletedId, 'c1');
  });

  group('手機寬度用下方面板', () {
    void useNarrowScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('點按鈕從下方滑出面板，列出比較', (WidgetTester tester) async {
      useNarrowScreen(tester);
      await pumpMenu(tester, MenuCallLog());
      await openMenu(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('王大明 的比較清單'), findsOneWidget);
      expect(find.text('醫療2'), findsOneWidget);
      expect(tester.getSize(find.byType(BottomSheet)).width, 375);
    });

    testWidgets('選一筆後面板收起，再打開比較', (WidgetTester tester) async {
      useNarrowScreen(tester);
      final MenuCallLog log = MenuCallLog();
      await pumpMenu(tester, log);
      await openMenu(tester);
      await tester.tap(find.text('醫療2'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(log.opened?.id, 'c2');
    });

    testWidgets('面板裡可以刪除，要先確認', (WidgetTester tester) async {
      useNarrowScreen(tester);
      final MenuCallLog log = MenuCallLog();
      await pumpMenu(tester, log);
      await openMenu(tester);
      await showRowActions(tester);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(log.deletedId, 'c1');
    });

    testWidgets('筆數很多時面板不超過 6 成螢幕，可以捲動', (WidgetTester tester) async {
      useNarrowScreen(tester);
      await pumpMenu(tester, MenuCallLog(), comparisonCount: 30);
      await openMenu(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SingleChildScrollView).last).height, lessThanOrEqualTo(812 * 0.6));
    });
  });

  testWidgets('批量管理時卡片不顯示按鈕；點按鈕不會打開客戶', (WidgetTester tester) async {
    int openCount = 0;
    Future<void> pumpCard(bool showComparisonMenu) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(AppThemeColors.deepSea),
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 240,
            child: CustomerCard(
              customer: const {'id': 'customer-1', 'name': '王大明'},
              onOpen: (Rect cardRect) => openCount++,
              showComparisonMenu: showComparisonMenu,
            ),
          ),
        ),
      ));
    }

    SavedComparisonService.instance.countByCustomer.value = {'customer-1': 1};
    await pumpCard(false);
    expect(find.textContaining('比較清單'), findsNothing);

    await pumpCard(true);
    await tester.pump();
    await tester.tap(find.textContaining('比較清單'));
    await tester.pump();
    expect(openCount, 0);
    await tester.pump(const Duration(seconds: 1));
  });
}
