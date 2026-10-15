import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/screens/customers/customer_form_dialog.dart';
import 'package:insurance_helper/screens/customers/customer_status_widgets.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_page.dart';
import 'package:insurance_helper/services/customer_export_service.dart';
import 'package:insurance_helper/services/customer_service.dart';

void main() {
  group('客戶狀態文字', () {
    test('符號與說明', () {
      expect(CustomerService.clientStatusSymbol('positive'), '✔');
      expect(CustomerService.clientStatusSymbol('considering'), '△');
      expect(CustomerService.clientStatusSymbol('negative'), '✖');
      expect(CustomerService.clientStatusSymbol(null), '');
      expect(CustomerService.clientStatusLabel(null), '未設定');
    });

    test('匯入：符號、中文、英文都認得，認不得的當未設定', () {
      expect(CustomerService.parseClientStatus('✔'), 'positive');
      expect(CustomerService.parseClientStatus('已成交'), 'positive');
      expect(CustomerService.parseClientStatus('△ 考慮中／待跟進'), 'considering');
      expect(CustomerService.parseClientStatus('X'), 'negative');
      expect(CustomerService.parseClientStatus('無意願'), 'negative');
      expect(CustomerService.parseClientStatus(''), isNull);
      expect(CustomerService.parseClientStatus('不知道'), isNull);
    });

    test('匯出再匯入回來一致；未設定是空白', () {
      for (final String? status in CustomerService.clientStatusOptions) {
        final String text = CustomerExportService.clientStatusText({'client_status': status});
        expect(CustomerService.parseClientStatus(text), status);
      }
      expect(CustomerExportService.clientStatusText({'client_status': null}), '');
    });
  });

  testWidgets('卡片名字旁的小標記：有設定才顯示', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            CustomerNameWithStatus(name: '王小明', status: 'considering', style: TextStyle()),
            CustomerNameWithStatus(name: '陳大同', status: null, style: TextStyle()),
          ],
        ),
      ),
    ));
    expect(find.text('△ 考慮中'), findsOneWidget);
    // 沒設定狀態的那位不放小標記
    expect(find.byType(CustomerStatusBadge), findsOneWidget);
    expect(find.text('✔ 有意願'), findsNothing);
  });

  testWidgets('客戶表單不能選狀態，只顯示狀態來源（4-2b）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    isOfflineMode = true;

    CustomerFormData? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showCustomerFormDialog(
              context,
              customer: {'id': 'c1', 'name': '王小明', 'nickname': '', 'phone': '', 'email': '', 'tags': <String>[], 'notes': '', 'gender': null, 'client_status': null},
              onSubmit: (CustomerFormData form) => submitted = form,
            ),
            child: const Text('打開'),
          ),
        ),
      ),
    ));
    // 表單裡有持續播放的動畫，改成固定等一下
    await tester.tap(find.text('打開'));
    await tester.pump(const Duration(milliseconds: 500));
    // 來源是讀完才顯示，多跑一個畫面
    await tester.pump(const Duration(milliseconds: 100));
    // 4-2b 起表單不能選狀態，只顯示狀態與來源
    expect(find.text('✔ 有意願'), findsNothing);
    expect(find.textContaining('記錄拜訪後自動帶入', findRichText: true), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(submitted?.name, '王小明');
  });

  testWidgets('客戶整頁：標題旁有狀態標記，基本資料顯示完整說明', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    isOfflineMode = true;
    OfflineDataStore.customers = [
      {'id': 'c5', 'name': '林美麗', 'nickname': '', 'phone': '', 'email': '', 'tags': <String>[], 'notes': '', 'custom_attributes': {}, 'client_status': 'negative', 'deleted_at': null},
    ];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CustomerDetailPage(customerId: 'c5'))));
    await tester.pumpAndSettle();
    expect(find.text('✖ 無意願'), findsOneWidget);
    // 沒有拜訪結果、但之前手動設過狀態：顯示狀態並說明之後會自動更新
    expect(find.textContaining('✖ 無意願／暫不考慮', findRichText: true), findsOneWidget);
    expect(find.textContaining('之前手動設定', findRichText: true), findsOneWidget);
  });
}
