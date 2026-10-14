import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/screens/customers/customer_form_dialog.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_page.dart';
import 'package:insurance_helper/services/customer_export_service.dart';
import 'package:insurance_helper/services/customer_service.dart';

void main() {
  group('性別文字轉換', () {
    test('顯示：男／女／不填', () {
      expect(CustomerService.genderLabel('male'), '男');
      expect(CustomerService.genderLabel('female'), '女');
      expect(CustomerService.genderLabel(null), '不填');
    });

    test('匯入：常見寫法都認得，認不得的當不填', () {
      expect(CustomerService.parseGender('男'), 'male');
      expect(CustomerService.parseGender(' M '), 'male');
      expect(CustomerService.parseGender('Female'), 'female');
      expect(CustomerService.parseGender('女性'), 'female');
      expect(CustomerService.parseGender(''), isNull);
      expect(CustomerService.parseGender('其他'), isNull);
    });

    test('匯出：沒填是空白，再匯入回來仍是不填（來回一致）', () {
      expect(CustomerExportService.genderText({'gender': 'male'}), '男');
      expect(CustomerExportService.genderText({'gender': null}), '');
      expect(CustomerService.parseGender(CustomerExportService.genderText({'gender': 'female'})), 'female');
      expect(CustomerService.parseGender(CustomerExportService.genderText({'gender': null})), isNull);
    });
  });

  testWidgets('客戶表單可以選性別，送出的資料帶著性別', (WidgetTester tester) async {
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
              customer: {'id': 'c1', 'name': '王小明', 'nickname': '', 'phone': '', 'email': '', 'tags': <String>[], 'notes': '', 'gender': null},
              onSubmit: (CustomerFormData form) => submitted = form,
            ),
            child: const Text('打開'),
          ),
        ),
      ),
    ));
    // 表單裡有持續播放的動畫，不能等「完全靜止」，改成固定等一下
    await tester.tap(find.text('打開'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('性別'), findsOneWidget);
    await tester.tap(find.text('女'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(submitted?.gender, 'female');
  });

  testWidgets('客戶細節整頁的基本資料顯示性別', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    isOfflineMode = true;
    OfflineDataStore.customers = [
      {'id': 'c9', 'name': '林美麗', 'nickname': '', 'phone': '', 'email': '', 'tags': <String>[], 'notes': '', 'custom_attributes': {}, 'gender': 'female', 'deleted_at': null},
    ];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CustomerDetailPage(customerId: 'c9'))));
    await tester.pumpAndSettle();
    expect(find.text('性別'), findsOneWidget);
    expect(find.text('女'), findsOneWidget);
  });
}
