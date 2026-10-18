import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/models/app_notification.dart';
import 'package:insurance_helper/services/notification_service.dart';
import 'package:insurance_helper/theme/app_theme.dart';
import 'package:insurance_helper/widgets/custom_toast.dart';
import 'package:insurance_helper/widgets/notification_arrival_card.dart';
import 'package:insurance_helper/widgets/notification_bell_button.dart';
import 'package:insurance_helper/widgets/notification_bell_controller.dart';
import 'package:insurance_helper/widgets/notification_center_popover.dart';

Map<String, dynamic> buildRow({required String id, String type = 'visit_record_ready', bool isRead = false}) {
  return {
    'id': id,
    'profile_id': 'u1',
    'type': type,
    'title': type == 'visit_record_failed' ? '拜訪紀錄整理失敗' : '拜訪紀錄已整理好',
    'content': '「2026/10/17 10:00 拜訪紀錄」已由 AI 整理完成，點這裡查看',
    'link_path': '/visit-records/r1',
    'target_visit_record_id': 'r1',
    'is_read': isRead,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };
}

// 首頁放一個鈴鐺；另有拜訪紀錄單篇頁，用來確認點通知會跳過去。
// [withWatcher] 為 true 時加上「新通知卡片」（主畫面實際的樣子）
Widget buildApp({bool withWatcher = false, String initialLocation = '/'}) {
  Widget page(String title) => Scaffold(
        appBar: AppBar(title: Text(title), actions: const [NotificationBellButton()]),
        body: withWatcher ? const NotificationArrivalWatcher() : const SizedBox.shrink(),
      );
  // 跟正式網址設定一樣：每一頁用同一個 page key，主畫面（含通知）換頁時不會重建
  const ValueKey<String> shellKey = ValueKey<String>('home-shell');
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (BuildContext context, GoRouterState state) => NoTransitionPage<void>(key: shellKey, child: page('首頁')),
      ),
      GoRoute(
        path: '/visit-records/:id',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(key: shellKey, child: page('單篇 ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

String? badgeText(WidgetTester tester) {
  final Badge badge = tester.widget<Badge>(find.byType(Badge));
  if (!badge.isLabelVisible) return null;
  final Text text = tester.widget<Text>(find.descendant(of: find.byType(Badge), matching: find.byType(Text)));
  return text.data;
}

void main() {
  final NotificationService service = NotificationService();

  setUp(() {
    isOfflineMode = true;
    service.clearForTest();
    NotificationBellController.instance.releaseAll();
  });

  group('通知資料', () {
    test('認得的類型會轉換；不認得的（例如舊的主管類型）略過', () {
      final AppNotification? ready = AppNotification.fromJson(buildRow(id: 'n1'));
      expect(ready?.type, NotificationType.visitRecordReady);
      expect(ready?.type.category, NotificationCategory.visitRecord);
      expect(ready?.linkPath, '/visit-records/r1');
      expect(AppNotification.fromJson(buildRow(id: 'n2', type: 'customer_reassigned')), isNull);
    });

    test('收到新通知：加到最前面、未讀數 +1、送出跳出提示；同一則不重複', () async {
      final List<AppNotification> arrived = [];
      final subscription = service.arrivals.listen(arrived.add);
      service.receiveNotificationRow(buildRow(id: 'n1'));
      service.receiveNotificationRow(buildRow(id: 'n2', type: 'visit_record_failed'));
      service.receiveNotificationRow(buildRow(id: 'n2', type: 'visit_record_failed'));
      await Future<void>.delayed(Duration.zero);

      expect(service.notifications.length, 2);
      expect(service.notifications.first.id, 'n2');
      expect(service.unreadCount, 2);
      expect(arrived.length, 2);
      await subscription.cancel();
    });

    test('標為已讀與全部已讀', () async {
      service.receiveNotificationRow(buildRow(id: 'n1'));
      service.receiveNotificationRow(buildRow(id: 'n2'));
      await service.markAsRead('n1');
      expect(service.unreadCount, 1);
      await service.markAllAsRead();
      expect(service.unreadCount, 0);
    });

    test('時間顯示：剛剛／分鐘前／小時前／天前', () {
      final DateTime now = DateTime(2026, 10, 17, 12, 0);
      expect(formatNotificationTime(now.subtract(const Duration(seconds: 20)), now), '剛剛');
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 5)), now), '5 分鐘前');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 3)), now), '3 小時前');
      expect(formatNotificationTime(now.subtract(const Duration(days: 2)), now), '2 天前');
    });
  });

  group('鈴鐺與通知清單', () {
    testWidgets('沒有通知：鈴鐺沒有數字，打開顯示「目前沒有通知」；分類只有全部與拜訪紀錄', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

      await tester.tap(find.byTooltip('通知'));
      await tester.pumpAndSettle();
      expect(find.text('目前沒有通知'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '拜訪紀錄'), findsOneWidget);
      expect(find.text('行程提醒'), findsNothing);
      expect(find.text('過戶通知'), findsNothing);
      expect(find.text('主管交辦'), findsNothing);
    });

    testWidgets('有未讀：鈴鐺顯示數字；點一則會變已讀並打開那一篇', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      service.receiveNotificationRow(buildRow(id: 'n1'));
      service.receiveNotificationRow(buildRow(id: 'n2', isRead: true));
      await tester.pump();
      expect(badgeText(tester), '1');

      await tester.tap(find.byTooltip('通知'));
      await tester.pumpAndSettle();
      expect(find.text('1 則未讀'), findsOneWidget);
      expect(find.byType(NotificationCard), findsNWidgets(2));

      // 新到舊：n2（已讀）在上面、n1（未讀）在下面
      await tester.tap(find.byType(NotificationCard).last);
      await tester.pumpAndSettle();
      expect(find.text('單篇 r1'), findsOneWidget);
      expect(service.unreadCount, 0);
    });

    testWidgets('手機寬度（375）打開通知清單不會超出畫面', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      service.receiveNotificationRow(buildRow(id: 'n1', type: 'visit_record_failed'));
      await tester.pump();
      await tester.tap(find.byTooltip('通知'));
      await tester.pumpAndSettle();
      expect(find.text('拜訪紀錄整理失敗'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('新通知卡片（從鈴鐺出來、收回鈴鐺）', () {
    testWidgets('卡片出現時數字先不加；5 秒後收進鈴鐺，數字變 1', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(withWatcher: true));
      service.receiveNotificationRow(buildRow(id: 'n1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NotificationArrivalCard), findsOneWidget);
      expect(find.text('拜訪紀錄已整理好'), findsOneWidget);
      expect(badgeText(tester), isNull);

      await tester.pump(NotificationArrivalCard.showDuration);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationArrivalCard), findsNothing);
      expect(badgeText(tester), '1');
    });

    testWidgets('卡片在鈴鐺下方，不會擋住鈴鐺', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(withWatcher: true));
      service.receiveNotificationRow(buildRow(id: 'n1'));
      await tester.pump(const Duration(milliseconds: 500));
      final Rect bellRect = tester.getRect(find.byTooltip('通知'));
      final Rect cardRect = tester.getRect(find.byType(NotificationArrivalCard));
      expect(cardRect.top, greaterThanOrEqualTo(bellRect.bottom));
      await tester.pump(NotificationArrivalCard.showDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('按 ✕ 收進鈴鐺；按「查看」打開那一篇且變已讀', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(withWatcher: true));
      service.receiveNotificationRow(buildRow(id: 'n1'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('收起'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationArrivalCard), findsNothing);
      expect(badgeText(tester), '1');

      service.receiveNotificationRow(buildRow(id: 'n2'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();
      expect(find.text('單篇 r1'), findsOneWidget);
      expect(service.notifications.firstWhere((AppNotification item) => item.id == 'n2').isRead, isTrue);
      expect(badgeText(tester), '1');
    });

    testWidgets('連續兩則：舊卡片先收進鈴鐺，畫面上只留新的一張', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(withWatcher: true));
      service.receiveNotificationRow(buildRow(id: 'n1'));
      await tester.pump(const Duration(milliseconds: 500));
      service.receiveNotificationRow(buildRow(id: 'n2', type: 'visit_record_failed'));
      // 第一格開始收回動畫，第二格動畫跑完，第三格把舊卡片拿掉
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.byType(NotificationArrivalCard), findsOneWidget);
      expect(find.text('拜訪紀錄整理失敗'), findsOneWidget);
      expect(badgeText(tester), '1');
      await tester.pump(NotificationArrivalCard.showDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('正在看那一篇時不跳卡片，鈴鐺直接 +1', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(withWatcher: true, initialLocation: '/visit-records/r1'));
      service.receiveNotificationRow(buildRow(id: 'n1'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationArrivalCard), findsNothing);
      expect(badgeText(tester), '1');
    });

    testWidgets('手機寬度（375）卡片左右撐滿、不超出畫面', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildApp(withWatcher: true));
      service.receiveNotificationRow(buildRow(id: 'n1', type: 'visit_record_failed'));
      await tester.pump(const Duration(milliseconds: 500));
      final Rect cardRect = tester.getRect(find.byType(NotificationArrivalCard));
      expect(cardRect.left, 12);
      expect(cardRect.right, 375 - 12);
      expect(tester.takeException(), isNull);
      await tester.pump(NotificationArrivalCard.showDuration);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('一般提示（CustomToast）白色主題是白底、深色主題是深底', (WidgetTester tester) async {
    Future<Color?> toastColor(ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => CustomToast.show(context, '儲存成功', ToastType.success),
            child: const Text('顯示'),
          ),
        ),
      ));
      await tester.tap(find.text('顯示'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final Container box = tester.widget<Container>(
        find.ancestor(of: find.text('儲存成功'), matching: find.byType(Container)).first,
      );
      final Color? color = (box.decoration as BoxDecoration?)?.color;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      return color;
    }

    // 2026-10-19 換皮後底色用主題的 surface（明亮白、深色深底）
    const AppAccent accent = AppThemeColors.defaultAccent;
    expect(await toastColor(AppTheme.light(accent)), AppColors.light(accent).surface);
    expect(await toastColor(AppTheme.dark(accent)), AppColors.dark(accent).surface);
  });
}
