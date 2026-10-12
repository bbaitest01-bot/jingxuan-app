import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('寄信次數超過上限翻成中文', () {
    const AuthException error = AuthException('email rate limit exceeded', statusCode: '429');
    expect(translateAuthError(error), contains('寄信次數已達上限'));
  });

  test('帳密錯誤翻成中文', () {
    const AuthException error = AuthException('Invalid login credentials');
    expect(translateAuthError(error), '帳號尚未註冊或密碼錯誤，請重新確認。');
  });

  test('對不到的錯誤保留原文', () {
    const AuthException error = AuthException('Something unexpected');
    expect(translateAuthError(error), 'Something unexpected');
  });
}
