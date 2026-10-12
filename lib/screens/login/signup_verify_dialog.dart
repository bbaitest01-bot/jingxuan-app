import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 註冊成功、需要驗證信箱時的說明視窗；按「返回登入」會呼叫 [onBackToLogin] 切回登入模式
void showSignupVerifyDialog(
  BuildContext context, {
  required String email,
  required VoidCallback onBackToLogin,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('✉️ 帳號建立成功 (需驗證 Email)'),
      content: Text(
        '您的帳號已成功建立！\n'
        '驗證信已寄送至：$email\n\n'
        '📌 登入指引：\n'
        '1. 請至 Email 收件匣點擊驗證連結（沒收到請檢查垃圾郵件）。\n'
        '2. 💡【重要提示】若您目前使用「無痕模式」，點擊 Email 連結後請將開啟的網址「複製並貼回此無痕視窗」，驗證方可生效。\n'
        '3. 完成驗證後，點擊下方「返回登入」即可直接輸入密碼登入！',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onBackToLogin();
          },
          child: const Text('返回登入'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ADB5),
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final url = Uri.parse('https://mail.google.com/');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('開啟信箱'),
        ),
      ],
    ),
  );
}
