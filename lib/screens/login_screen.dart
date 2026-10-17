import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../router/app_routes.dart';
import '../services/auth_error_messages.dart';
import '../services/auth_status_service.dart';
import '../services/login_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/forgot_password_dialog.dart';
import '../theme/app_theme.dart';
import 'login/login_brand_panel.dart';
import 'login/login_form_card.dart';
import 'login/login_offline_banner.dart';
import 'login/login_theme_toggle.dart';
import 'login/signup_verify_dialog.dart';

/// 登入頁（網址 /login）的外框：保管表單狀態，處理登入、註冊、Google 登入。
/// 畫面區塊在 `login/` 資料夾；呼叫 Supabase 在 `LoginService`。
/// 登入成功後不用自己換頁，守門規則會自動導到今日行程（或原本要去的網址）。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamCodeController = TextEditingController(text: 'TAIPEI-01');
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrlErrors();
    });
  }

  void _checkUrlErrors() {
    if (kIsWeb) {
      // 守門規則把驗證錯誤參數帶到登入頁網址上，從目前路由讀取
      final uri = GoRouterState.of(context).uri;
      final error = uri.queryParameters['error'];
      final errorCode = uri.queryParameters['error_code'];

      if (errorCode == 'otp_expired' || (error != null && error.isNotEmpty)) {
        CustomToast.show(
          context,
          '⚠️ 驗證連結已過期或失效！若您收到了多封驗證信，請務必點擊「最新發出的那一封」，或在下方重試登入/發送。',
          ToastType.warning,
          actionLabel: '重發驗證信',
          onActionPressed: () {
            setState(() {
              _isSignUp = false;
            });
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _teamCodeController.dispose();
    super.dispose();
  }

  // 按下登入／註冊：檢查表單後，依目前模式註冊或登入
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (isOfflineMode) {
      CustomToast.show(context, '離線模式下無法註冊/登入。請填寫您的 .env 金鑰，或使用上方橫幅的「直接跳過登入」。', ToastType.warning);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        await _signUp();
      } else {
        await LoginService.instance.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          CustomToast.show(context, '登入成功！歡迎回來', ToastType.success);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // 信箱還沒驗證：提示並提供「重發驗證信」；其他錯誤翻成中文顯示
        if (e.message.contains('Email not confirmed')) {
          _showEmailNotConfirmedToast();
          return;
        }
        CustomToast.show(context, translateAuthError(e), ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '操作失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Email 註冊：已註冊過就切回登入模式；需要驗證信箱就顯示說明視窗
  Future<void> _signUp() async {
    final SignUpResult result = await LoginService.instance.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _nameController.text.trim(),
      teamCode: _teamCodeController.text.trim(),
    );
    if (!mounted) return;

    if (result.isAlreadyRegistered) {
      CustomToast.show(
        context,
        '⚠️ 此 Email (${_emailController.text.trim()}) 已經被註冊過囉！已為您帶入帳號並切換至登入模式。',
        ToastType.warning,
      );
      setState(() {
        _isSignUp = false;
      });
      return;
    }

    if (result.needsEmailVerification) {
      showSignupVerifyDialog(
        context,
        email: _emailController.text.trim(),
        onBackToLogin: () {
          setState(() {
            _isSignUp = false;
          });
        },
      );
    } else {
      CustomToast.show(context, '註冊成功！已自動登入。', ToastType.success);
    }
  }

  // 信箱尚未驗證的提示，附「重發驗證信」
  void _showEmailNotConfirmedToast() {
    CustomToast.show(
      context,
      '電子信箱尚未完成驗證！請至 Email 收件匣點擊「最新的」驗證連結。',
      ToastType.warning,
      actionLabel: '重發驗證信',
      onActionPressed: () async {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          CustomToast.show(context, '請先在上方填寫您的 Email 帳號', ToastType.warning);
          return;
        }
        try {
          await LoginService.instance.resendSignupEmail(email);
          if (mounted) {
            CustomToast.show(context, '全新驗證信已寄出！請至 Email 收件匣點擊最新信件。', ToastType.success);
          }
        } catch (resendErr) {
          if (mounted) {
            CustomToast.show(context, '重發失敗：${translateAuthError(resendErr)}', ToastType.error);
          }
        }
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (isOfflineMode) {
      CustomToast.show(context, '離線模式下無法使用 Google 登入。請使用上方橫幅的「直接跳過登入」。', ToastType.warning);
      return;
    }

    // Google 登入會離開網站再回到首頁，網址上的 from 會不見，先存起來，回來後才能導回原本的頁面
    final String? fromLocation = GoRouterState.of(context).uri.queryParameters['from'];
    await AuthStatusService.instance.saveReturnLocation(fromLocation);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await LoginService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Google 登入發起失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 「常用信箱網域」：把選到的網域接在信箱後面（已經有 @ 就換掉原本的網域）
  void _appendEmailDomain(String domain) {
    final currentText = _emailController.text.trim();
    if (currentText.isEmpty) {
      _emailController.text = domain;
    } else if (currentText.contains('@')) {
      final prefix = currentText.split('@')[0];
      _emailController.text = '$prefix$domain';
    } else {
      _emailController.text = '$currentText$domain';
    }
    _emailController.selection = TextSelection.fromPosition(
      TextPosition(offset: _emailController.text.length),
    );
    setState(() {});
  }

  // 切換登入／註冊模式；切到註冊時邀請碼空白就帶入預設值
  void _toggleSignUpMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      if (_isSignUp && _teamCodeController.text.trim().isEmpty) {
        _teamCodeController.text = 'TAIPEI-01';
      }
    });
  }

  void _openForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );
  }

  // 寬度超過這個值才左右兩欄；手機與窄視窗改成上下排列
  static const double _twoColumnMinWidth = 900;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          // 離線預覽模式：最上方的提示列，附「直接跳過登入」
          if (isOfflineMode)
            LoginOfflineBanner(
              reason: offlineReason,
              // 離線預覽：標記已跳過登入，守門規則就會放行到今日行程
              onSkipLogin: () {
                AuthStatusService.instance.enterOfflinePreview();
                context.go(AppRoutes.schedule);
              },
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= _twoColumnMinWidth) {
                  return _buildTwoColumnLayout(constraints);
                }
                return _buildStackedLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  // 寬螢幕：左欄品牌、右欄表單
  Widget _buildTwoColumnLayout(BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            // 視窗太矮時左欄可以捲動，不會溢出
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const IntrinsicHeight(child: LoginBrandPanel()),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: _buildForm(),
                ),
              ),
              const Positioned(top: 16, right: 16, child: LoginThemeToggle()),
            ],
          ),
        ),
      ],
    );
  }

  // 窄螢幕：精簡品牌在上、表單在下，一起捲動
  Widget _buildStackedLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Stack(
            children: [
              LoginBrandPanel(isCompact: true),
              Positioned(top: 12, right: 12, child: LoginThemeToggle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: _formKey,
        child: LoginFormCard(
          isSignUp: _isSignUp,
          isLoading: _isLoading,
          obscurePassword: _obscurePassword,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          onSubmit: _handleSubmit,
          onGoogleSignIn: _handleGoogleSignIn,
          onToggleObscurePassword: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          onToggleSignUp: _toggleSignUpMode,
          onForgotPassword: _openForgotPasswordDialog,
          onDomainSelected: _appendEmailDomain,
        ),
      ),
    );
  }
}
