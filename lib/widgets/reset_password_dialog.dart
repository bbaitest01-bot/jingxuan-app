import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/app_localizations.dart';
import '../theme/app_theme.dart';
import 'auth_dialog_parts.dart';
import 'custom_toast.dart';

class ResetPasswordDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ResetPasswordDialog({
    super.key,
    this.onSuccess,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (isOfflineMode) {
      setState(() {
        _errorMessage = '⚠️ 離線預覽模式下無法更換密碼。請配置 .env 金鑰後重試。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPassword = _passwordController.text.trim();
      
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // 提示要在視窗還開著時貼上畫面（等這一格畫完），之後關掉視窗提示仍會留著
        CustomToast.show(context, '密碼設定成功！', ToastType.success);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;

        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '密碼設定失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 密碼欄的「顯示／隱藏」按鈕
  Widget _visibilityButton(bool isObscured, VoidCallback onPressed) {
    IconData icon = Icons.visibility_outlined;
    if (isObscured) {
      icon = Icons.visibility_off_outlined;
    }
    return IconButton(icon: Icon(icon, size: 20), onPressed: onPressed);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? errorMessage = _errorMessage;
    Widget confirmButtonChild = Text(context.l10n('confirm'));
    if (_isLoading) {
      confirmButtonChild = const ButtonSpinner();
    }

    // 底色、圓角、框線來自主題的 DialogTheme；輸入框樣式來自主題
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthDialogHeader(icon: Icons.key_rounded, title: context.l10n('reset_password_title')),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n('new_password_label'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: _visibilityButton(_obscurePassword, () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    }),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入新密碼';
                    }
                    if (value.length < 6) {
                      return '密碼長度至少需 6 個字元';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleUpdatePassword(),
                  decoration: InputDecoration(
                    labelText: context.l10n('confirm_new_password_label'),
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: _visibilityButton(_obscureConfirmPassword, () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    }),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請再次輸入新密碼';
                    }
                    if (value != _passwordController.text) {
                      return context.l10n('passwords_do_not_match');
                    }
                    return null;
                  },
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  AuthErrorBox(message: errorMessage),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: colors.ink2),
                      child: Text(context.l10n('cancel')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleUpdatePassword,
                      child: confirmButtonChild,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
