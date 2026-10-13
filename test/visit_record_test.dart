import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/models/visit_record.dart';
import 'package:insurance_helper/router/app_redirect.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/services/auth_status_service.dart';
import 'package:insurance_helper/services/visit_record_service.dart';

void main() {
  group('網址', () {
    test('列表與單篇網址，側邊欄名稱是「拜訪紀錄」', () {
      expect(AppRoutes.visitRecords, '/visit-records');
      expect(AppRoutes.visitRecordPath('abc'), '/visit-records/abc');
      expect(AppRoutes.menuForPath('/visit-records'), '拜訪紀錄');
    });

    test('未登入開單篇網址會導到登入頁並記住原網址；登入的業務員可以直接進入', () {
      const AuthSnapshot signedOut = AuthSnapshot(
        isOffline: false,
        hasEnteredOfflinePreview: false,
        isPasswordRecovery: false,
        isSignedIn: false,
        profileStatus: null,
        profileRole: 'agent',
      );
      final String? location = decideRedirect(Uri.parse('/visit-records/abc'), signedOut).location;
      expect(location, '/login?from=%2Fvisit-records%2Fabc');

      const AuthSnapshot agent = AuthSnapshot(
        isOffline: false,
        hasEnteredOfflinePreview: false,
        isPasswordRecovery: false,
        isSignedIn: true,
        profileStatus: 'active',
        profileRole: 'agent',
      );
      expect(decideRedirect(Uri.parse('/visit-records/abc'), agent).location, isNull);
    });
  });

  group('VisitRecord', () {
    test('預設標題是日期時間', () {
      expect(VisitRecord.defaultTitle(DateTime(2026, 10, 14, 9, 5)), '2026/10/14 09:05 拜訪紀錄');
    });
  });

  group('離線模式：新增 → 讀取 → 修改', () {
    setUp(() {
      isOfflineMode = true;
      VisitRecordService.instance.clearOfflineRecordsForTest();
    });

    test('新增時標題空白會用預設標題，內容存在原始轉錄', () async {
      final VisitRecord record = await VisitRecordService.instance.createRecord(title: '  ', rawTranscript: '拜訪王先生');
      expect(record.title.endsWith('拜訪紀錄'), isTrue);
      expect(record.rawTranscript, '拜訪王先生');
      expect(record.status, VisitRecord.statusRaw);
      expect((await VisitRecordService.instance.fetchMyRecords()).length, 1);
    });

    test('修改只改標題與整理後內容，原始轉錄保留', () async {
      final VisitRecord record = await VisitRecordService.instance.createRecord(title: '第一篇', rawTranscript: '原文');
      await VisitRecordService.instance.updateRecord(record.id, title: '改過的標題', organizedContent: '整理後');
      final VisitRecord? reloaded = await VisitRecordService.instance.fetchRecord(record.id);
      expect(reloaded?.title, '改過的標題');
      expect(reloaded?.organizedContent, '整理後');
      expect(reloaded?.rawTranscript, '原文');
      expect(reloaded?.previewText, '整理後');
    });

    test('找不到的編號回傳 null', () async {
      expect(await VisitRecordService.instance.fetchRecord('not-exist'), isNull);
    });
  });
}
