import 'package:supabase_flutter/supabase_flutter.dart';

/// 把 Supabase 登入／註冊／寄信回傳的英文錯誤，翻成使用者看得懂的中文。
/// 註冊、登入、重發驗證信、忘記密碼共用；對不到的錯誤就保留原文，方便回報問題。
String translateAuthError(Object error) {
  String message = error.toString();
  String? statusCode;
  if (error is AuthException) {
    message = error.message;
    statusCode = error.statusCode;
  }

  // 寄信次數超過上限：Supabase 內建寄信服務每小時只能寄少量信件（註冊驗證信、忘記密碼信都算）
  if (message.contains('rate limit') || statusCode == '429') {
    return '寄信次數已達上限，請約一小時後再試；或先改用 Google 登入。';
  }
  // 同一個信箱短時間內重複要求寄信
  if (message.contains('For security purposes')) {
    return '操作太頻繁，請稍等一分鐘後再試。';
  }
  if (message.contains('User already registered') || message.contains('already exists')) {
    return '此 Email 已被註冊！請直接切換至「業務員登入」或點擊「忘記密碼」。';
  }
  // 重設密碼時，新密碼和舊密碼一樣
  if (message.contains('should be different from the old password')) {
    return '新密碼不能與舊密碼相同，請換一組新密碼。';
  }
  if (message.contains('Password should be at least')) {
    return '密碼長度不足，請輸入至少 6 位字元。';
  }
  if (message.contains('Invalid login credentials')) {
    return '帳號尚未註冊或密碼錯誤，請重新確認。';
  }
  return message;
}
