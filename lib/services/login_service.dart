import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email 註冊的結果
class SignUpResult {
  /// 這個 Email 已經註冊過（Supabase 回傳的使用者沒有任何登入方式）
  final bool isAlreadyRegistered;

  /// 需要先到信箱點驗證連結（Supabase 沒有直接給登入狀態）
  final bool needsEmailVerification;

  const SignUpResult({required this.isAlreadyRegistered, required this.needsEmailVerification});
}

/// 登入頁用到的 Supabase 帳號動作：Email 註冊、Email 登入、Google 登入、重發驗證信。
/// 錯誤一律往外丟，由畫面翻成中文提示（translateAuthError）。
class LoginService {
  static final LoginService instance = LoginService._internal();
  LoginService._internal();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// 驗證信、Google 登入完成後要回到的網址：網頁版用目前網站；
  /// 本機開發時若不是 8080 埠，固定回 localhost:8080（Supabase 允許清單裡的網址）
  String authRedirectUrl() {
    if (!kIsWeb) return 'http://localhost:8080';
    final String origin = Uri.base.origin;
    if (origin.contains('localhost') && !origin.contains(':8080')) {
      return 'http://localhost:8080';
    }
    return origin;
  }

  /// Email 註冊。只送姓名與邀請碼；角色、帳號狀態、團隊一律由資料庫建立帳號時決定，前端不能指定
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String teamCode,
  }) async {
    final AuthResponse response = await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: authRedirectUrl(),
      data: {
        'full_name': fullName,
        'team_code': teamCode,
      },
    );

    // Supabase 對已註冊的 Email 會回傳一個沒有任何登入方式（identities 為空）的使用者
    final User? user = response.user;
    final bool isAlreadyRegistered = user != null && (user.identities?.isEmpty ?? false);
    return SignUpResult(
      isAlreadyRegistered: isAlreadyRegistered,
      needsEmailVerification: response.session == null,
    );
  }

  /// Email＋密碼登入；成功後由 AuthStatusService 收到通知，守門規則自動導向
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// Google 登入：會離開網站到 Google，完成後回到 [authRedirectUrl]
  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectUrl(),
      queryParams: {
        'prompt': 'select_account',
      },
    );
  }

  /// 重發註冊驗證信
  Future<void> resendSignupEmail(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }
}
