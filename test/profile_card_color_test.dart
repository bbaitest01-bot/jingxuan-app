import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/profile_service.dart';

void main() {
  test('顏色轉成 #RRGGBB 存進資料庫', () {
    expect(ProfileService.colorToHex(const Color(0xFF8B5CF6)), '#8B5CF6');
  });

  test('#RRGGBB 轉回顏色，存與讀一致', () {
    const Color original = Color(0xFF10B981);
    expect(ProfileService.colorFromHex(ProfileService.colorToHex(original)), original);
  });

  test('格式不對或沒有值時回傳 null（沿用預設顏色）', () {
    expect(ProfileService.colorFromHex(null), isNull);
    expect(ProfileService.colorFromHex('8B5CF6'), isNull);
    expect(ProfileService.colorFromHex('#GGGGGG'), isNull);
  });
}
