import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/app_localizations.dart';
import '../services/auth_error_messages.dart';
import '../theme/app_theme.dart';
import 'auth_dialog_parts.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordDialog({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    if (isOfflineMode) {
      setState(() {
        _errorMessage = '⚠️ 離線預覽模式下無法發送 Email。請於 .env 配置有效金鑰後再試。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      
      // Determine dynamic redirect URL for Web/App (預設引導至 port 8080)
      String? redirectTo;
      if (kIsWeb) {
        final origin = Uri.base.origin;
        redirectTo = (origin.contains('localhost') && !origin.contains(':8080'))
            ? 'http://localhost:8080'
            : origin;
      } else {
        redirectTo = 'http://localhost:8080';
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      if (mounted) {
        setState(() {
          _isSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '發送失敗：${translateAuthError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 底色、圓角、框線來自主題的 DialogTheme
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isSent ? _buildSuccessView(context) : _buildFormView(context),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? errorMessage = _errorMessage;
    Widget sendButtonChild = Text(context.l10n('send_reset_link'));
    if (_isLoading) {
      sendButtonChild = const ButtonSpinner();
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthDialogHeader(icon: Icons.lock_reset_rounded, title: context.l10n('forgot_password_title')),
          const SizedBox(height: 16),
          Text(
            context.l10n('forgot_password_desc'),
            style: TextStyle(color: colors.ink2, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendResetLink(),
            decoration: InputDecoration(
              labelText: context.l10n('email_label'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n('enter_email_hint');
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return context.l10n('enter_valid_email_hint');
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
                onPressed: _isLoading ? null : _handleSendResetLink,
                child: sendButtonChild,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.okSoft, shape: BoxShape.circle),
          child: Icon(Icons.mark_email_read_rounded, color: colors.ok, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n('reset_link_sent_title'),
          style: AppTextStyles.serif(fontSize: 18, color: colors.ink),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n('reset_link_sent_desc'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.ink2, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n('done')),
          ),
        ),
      ],
    );
  }
}
