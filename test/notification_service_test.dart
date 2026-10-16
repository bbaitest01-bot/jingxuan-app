import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart' show isOfflineMode;
import 'package:insurance_helper/services/notification_service.dart';

void main() {
  test('一開始沒有任何通知（假資料已移除，問題 M1）；離線預覽不連資料庫', () async {
    isOfflineMode = true;
    final NotificationService service = NotificationService();
    service.clearForTest();
    await service.start();
    expect(service.notifications, isEmpty);
    expect(service.unreadCount, 0);
  });
}
