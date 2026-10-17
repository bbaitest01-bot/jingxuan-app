import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_sign_in_button.dart';
import 'email_domain_picker.dart';

/// 登入頁右欄的表單：標題、姓名（註冊時）、信箱、密碼、忘記密碼、登入／註冊按鈕、Google 登入、切換登入與註冊。
/// 只負責畫面；按下按鈕後要做的事由外框（LoginScreen）提供。
class LoginFormCard extends StatelessWidget {
  final bool isSignUp;
  final bool isLoading;
  final bool obscurePassword;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onToggleSignUp;
  final VoidCallback onForgotPassword;
  final ValueChanged<String> onDomainSelected;

  const LoginFormCard({
    super.key,
    required this.isSignUp,
    required this.isLoading,
    required this.obscurePassword,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.onGoogleSignIn,
    required this.onToggleObscurePassword,
    required this.onToggleSignUp,
    required this.onForgotPassword,
    required this.onDomainSelected,
  });

  // 輸入框內距：搭配 15 號字，整個框高約 46
  static const EdgeInsets _fieldPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 13);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    String title = '登入';
    String subtitle = '歡迎回來，請使用你的帳號登入。';
    if (isSignUp) {
      title = '建立業務帳號';
      subtitle = '填寫資料申請使用，送出後請到信箱完成驗證。';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.serif(fontSize: 28, color: colors.ink)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 14, color: colors.ink2)),
        const SizedBox(height: 32),

        // 姓名（只有註冊時出現）
        if (isSignUp) ...[
          const _FieldLabel(text: '姓名'),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(hintText: '例：王大明（綽號也可以）', contentPadding: _fieldPadding),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '請輸入姓名';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
        ],

        // 電子信箱：標籤右邊是「常用信箱網域」快選
        _FieldLabel(text: '電子信箱', trailing: EmailDomainPicker(onSelected: onDomainSelected)),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15),
          decoration: const InputDecoration(hintText: 'name@example.com', contentPadding: _fieldPadding),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '請輸入 Email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return '請輸入有效的 Email 格式';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // 密碼：登入時標籤右邊是「忘記密碼？」
        _FieldLabel(text: '密碼', trailing: isSignUp ? null : _ForgotPasswordLink(onPressed: onForgotPassword)),
        _buildPasswordField(colors),
        const SizedBox(height: 28),

        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: isLoading ? null : onSubmit,
            child: _buildSubmitLabel(colors),
          ),
        ),
        const SizedBox(height: 24),
        const _OrDivider(),
        const SizedBox(height: 24),
        GoogleStyleSignInButton(
          onPressed: onGoogleSignIn,
          label: '使用 Google 帳號登入',
          isLoading: isLoading,
        ),
        const SizedBox(height: 28),
        _buildSwitchModeRow(colors),
      ],
    );
  }

  Widget _buildPasswordField(AppColors colors) {
    IconData visibilityIcon = Icons.visibility_outlined;
    if (obscurePassword) {
      visibilityIcon = Icons.visibility_off_outlined;
    }
    return TextFormField(
      controller: passwordController,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 15),
      onFieldSubmitted: (_) {
        if (!isLoading) {
          onSubmit();
        }
      },
      decoration: InputDecoration(
        hintText: '至少 6 個字元',
        contentPadding: _fieldPadding,
        suffixIcon: IconButton(
          icon: Icon(visibilityIcon, size: 20, color: colors.ink3),
          tooltip: '顯示／隱藏密碼',
          onPressed: onToggleObscurePassword,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '請輸入密碼';
        }
        if (value.length < 6) {
          return '密碼長度需至少 6 個字元';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitLabel(AppColors colors) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAcc),
      );
    }
    if (isSignUp) {
      return const Text('註冊帳號', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
    }
    return const Text('登入', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
  }

  // 最下面：「還沒有帳號？申請使用」或「已有帳號？返回登入」
  Widget _buildSwitchModeRow(AppColors colors) {
    String question = '還沒有帳號？';
    String actionLabel = '申請使用';
    if (isSignUp) {
      question = '已有帳號？';
      actionLabel = '返回登入';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(question, style: TextStyle(fontSize: 14, color: colors.ink2)),
        TextButton(
          onPressed: onToggleSignUp,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// 輸入框上方的欄位名稱，右邊可放一個小按鈕
class _FieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const _FieldLabel({required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appColors.ink),
        ),
      ),
    ];
    final Widget? trailingWidget = trailing;
    if (trailingWidget != null) {
      children.add(trailingWidget);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(height: 24, child: Row(children: children)),
    );
  }
}

/// 「忘記密碼？」文字連結
class _ForgotPasswordLink extends StatelessWidget {
  final VoidCallback onPressed;

  const _ForgotPasswordLink({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('忘記密碼？', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

/// 兩條細線中間一個「或」
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('或', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ),
        Expanded(child: Divider(color: colors.line, height: 1)),
      ],
    );
  }
}
