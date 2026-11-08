import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/google_access_token_service.dart';

void main() {
  group('Google 通行證新不新鮮（L4，2026-11-08）', () {
    final DateTime now = DateTime(2026, 11, 8, 15, 0);

    test('拿到 10 分鐘：還新鮮，直接用', () {
      final int savedAt = now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
      expect(GoogleAccessTokenService.isTokenFresh(savedAt, now), isTrue);
    });

    test('拿到 55 分鐘：太舊，要換新', () {
      final int savedAt = now.subtract(const Duration(minutes: 55)).millisecondsSinceEpoch;
      expect(GoogleAccessTokenService.isTokenFresh(savedAt, now), isFalse);
    });

    test('沒記過時間或被標成過期（0）：一律換新', () {
      expect(GoogleAccessTokenService.isTokenFresh(0, now), isFalse);
    });
  });
}
