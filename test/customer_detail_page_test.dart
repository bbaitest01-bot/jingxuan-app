import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode, OfflineDataStore;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/router/app_redirect.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/screens/customers/detail/customer_detail_page.dart';
import 'package:insurance_helper/services/auth_status_service.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

const AuthSnapshot agent = AuthSnapshot(
  isOffline: false,
  hasEnteredOfflinePreview: false,
  isPasswordRecovery: false,
  isSignedIn: true,
  profileStatus: 'active',
  profileRole: 'agent',
);

Future<void> pumpPage(WidgetTester tester, String customerId) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomerDetailPage(customerId: customerId))));
  await tester.pumpAndSettle();
}

void main() {
  test('客戶細節網址：/customers/:id，登入的業務員可直接進入', () {
    expect(AppRoutes.customerPath('abc'), '/customers/abc');
    expect(decideRedirect(Uri.parse('/customers/abc'), agent).location, isNull);
  });

  group('離線模式的客戶細節頁', () {
    setUp(() {
      isOfflineMode = true;
      VisitRecordService.instance.clearOfflineRecordsForTest();
      OfflineDataStore.customers = [
        {
          'id': 'c1',
          'name': '王小明',
          'nickname': '小明',
          'phone': '0912345678',
          'email': '',
          'tags': ['高資產'],
          'notes': '喜歡打高爾夫',
          'custom_attributes': {'生日': '1990/01/01'},
          'deleted_at': null,
        },
      ];
    });

    testWidgets('顯示基本資料、保單、拜訪紀錄區塊；拜訪紀錄只列連結這位客戶的', (WidgetTester tester) async {
      final VisitRecordService service = VisitRecordService.instance;
      final VisitRecord linked = await service.createRecord(title: '拜訪王小明', rawTranscript: '談醫療險');
      await service.updateCustomerLink(linked, const VisitCustomerOption(id: 'c1', name: '王小明'));
      await service.createRecord(title: '沒連結的紀錄', rawTranscript: '其他');

      await pumpPage(tester, 'c1');
      expect(find.text('王小明（小明）'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('1990/01/01'), findsOneWidget);
      expect(find.text('喜歡打高爾夫'), findsOneWidget);
      expect(find.text('保單（0 張）'), findsOneWidget);
      expect(find.text('拜訪紀錄（1）'), findsOneWidget);
      expect(find.text('拜訪王小明'), findsOneWidget);
      expect(find.text('沒連結的紀錄'), findsNothing);
    });

    testWidgets('找不到的客戶顯示提示與返回按鈕', (WidgetTester tester) async {
      await pumpPage(tester, 'not-exist');
      expect(find.textContaining('找不到這位客戶'), findsOneWidget);
      expect(find.text('返回客戶管理'), findsOneWidget);
    });
  });
}
