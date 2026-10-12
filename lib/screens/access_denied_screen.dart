import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 帳號已停用、刪除，或查不到 profile 時顯示的頁面（網址 /denied）。
/// 按「返回登入頁」會登出，守門規則就會自動帶回登入頁。
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: errorColor),
              const SizedBox(height: 16),
              const Text('此帳號目前無法使用系統',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('帳號可能已停用、刪除，或尚未完成設定；請聯絡管理員。',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('返回登入頁'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
