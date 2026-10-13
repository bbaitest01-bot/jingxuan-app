import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/notification_service.dart';

void main() {
  test('一開始沒有任何通知（假資料已移除，問題 M1）', () {
    final NotificationService service = NotificationService();
    expect(service.notifications, isEmpty);
    expect(service.unreadCount, 0);
  });
}
