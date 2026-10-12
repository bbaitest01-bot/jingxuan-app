import 'package:flutter/material.dart';
import '../../widgets/google_sign_in_button.dart';
import 'email_domain_picker.dart';

/// 登入頁中間的卡片：姓名（註冊時）、信箱、密碼、忘記密碼、登入／註冊按鈕、Google 登入、切換登入與註冊。
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFF1E293B), // Border color Slate 800
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSignUp ? '建立業務帳號' : '業務員登入',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Name Input (Only shown on Sign Up)
            if (isSignUp) ...[
              TextFormField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '姓名 (綽號就好惹~)',
                  hintText: '例：王大明',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入姓名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Email Input Label & Quick Domain Selector
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '電子信箱',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                EmailDomainPicker(onSelected: onDomainSelected),
              ],
            ),
            const SizedBox(height: 8),

            // Email Input
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '請輸入 Email 帳號',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入 Email';
                }
                if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value.trim())) {
                  return '請輸入有效的 Email 格式';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!isLoading) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: '密碼',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white54,
                  ),
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
            ),
            if (!isSignUp) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '忘記密碼？',
                    style: TextStyle(
                      color: Color(0xFF00ADB5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ADB5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Colors.white),
                      ),
                    )
                  : Text(isSignUp ? '註冊帳號' : '登入'),
            ),
            const SizedBox(height: 16),

            // Divider
            const Row(
              children: [
                Expanded(
                    child: Divider(color: Colors.white24)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '或使用第三方帳號',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white54),
                  ),
                ),
                Expanded(
                    child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 16),

            // Google Sign-In Button
            GoogleStyleSignInButton(
              onPressed: onGoogleSignIn,
              label: '使用 Google 繼續',
              isLoading: isLoading,
            ),
            const SizedBox(height: 12),

            // Toggle Sign In / Sign Up
            TextButton(
              onPressed: onToggleSignUp,
              child: Text(
                isSignUp ? '已有帳號？返回登入' : '沒有帳號？立即註冊一個',
                style: const TextStyle(
                  color: Color(0xFF00ADB5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
