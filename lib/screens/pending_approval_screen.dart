import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback? onRefreshStatus;

  const PendingApprovalScreen({
    super.key,
    required this.userEmail,
    this.onRefreshStatus,
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      if (isOfflineMode) {
        CustomToast.show(context, '離線模式下無連線審核數據。', ToastType.warning);
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('status')
            .eq('id', user.id)
            .maybeSingle();

        final status = data?['status'] as String? ?? 'pending';
        if (mounted) {
          if (status == 'active') {
            CustomToast.show(context, '🎉 您的帳號已成功獲准開通！', ToastType.success);
            widget.onRefreshStatus?.call();
          } else {
            CustomToast.show(context, '📋 帳號仍在審核中，請耐心地等待主管開通。', ToastType.warning);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '檢查失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      // 登出後守門規則會自動帶回登入頁
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '登出失敗: $e', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget refreshIcon = const Icon(Icons.refresh_rounded, size: 18);
    String refreshLabel = '重新整理審核狀態';
    if (_isChecking) {
      refreshIcon = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAcc),
      );
      refreshLabel = '檢查中...';
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            // 卡片底色、細框、圓角來自主題的 CardTheme
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: colors.warnSoft, shape: BoxShape.circle),
                        child: Icon(Icons.pending_actions_rounded, size: 32, color: colors.warn),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '帳號審核中',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.serif(fontSize: 22, color: colors.ink),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '您的帳號已成功完成驗證！\n'
                      '登入帳號：${widget.userEmail}\n'
                      '申請通訊處：國泰台北第一通訊處 (TAIPEI-01)\n\n'
                      '基於通訊處個資與客戶資產安全防護，新註冊帳號需由「團隊主管」於戰情室進行身分確認並點擊開通後，方可登入存取系統。',
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: 13, height: 1.6, color: colors.ink2),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _isChecking ? null : _checkStatus,
                        icon: refreshIcon,
                        label: Text(refreshLabel),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _handleSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('返回登入頁'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
