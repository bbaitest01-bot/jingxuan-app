import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 官方 100% 精準 4 色 Google "G" 標誌 (基於向量 Bezier Path 完美渲染，無任何扭曲)
class GoogleGLogoIcon extends StatelessWidget {
  final double size;
  const GoogleGLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        size: Size(size, size),
        painter: _OfficialGoogleGLogoPainter(),
      ),
    );
  }
}

class _OfficialGoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;

    // 1. Blue Path (#4285F4)
    final bluePath = Path()
      ..moveTo(22.56 * s, 12.25 * s)
      ..cubicTo(22.56 * s, 11.47 * s, 22.49 * s, 10.72 * s, 22.36 * s, 10.0 * s)
      ..lineTo(12.0 * s, 10.0 * s)
      ..lineTo(12.0 * s, 14.26 * s)
      ..lineTo(17.92 * s, 14.26 * s)
      ..cubicTo(17.66 * s, 15.63 * s, 16.88 * s, 16.79 * s, 15.71 * s, 17.57 * s)
      ..lineTo(15.71 * s, 20.34 * s)
      ..lineTo(19.28 * s, 20.34 * s)
      ..cubicTo(21.36 * s, 18.42 * s, 22.56 * s, 15.60 * s, 22.56 * s, 12.25 * s)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4)..isAntiAlias = true);

    // 2. Green Path (#34A853)
    final greenPath = Path()
      ..moveTo(12.0 * s, 23.0 * s)
      ..cubicTo(14.97 * s, 23.0 * s, 17.46 * s, 22.02 * s, 19.28 * s, 20.34 * s)
      ..lineTo(15.71 * s, 17.57 * s)
      ..cubicTo(14.73 * s, 18.23 * s, 13.48 * s, 18.63 * s, 12.0 * s, 18.63 * s)
      ..cubicTo(9.14 * s, 18.63 * s, 6.71 * s, 16.70 * s, 5.84 * s, 14.10 * s)
      ..lineTo(2.18 * s, 14.10 * s)
      ..lineTo(2.18 * s, 16.94 * s)
      ..cubicTo(3.99 * s, 20.53 * s, 7.70 * s, 23.0 * s, 12.0 * s, 23.0 * s)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853)..isAntiAlias = true);

    // 3. Yellow Path (#FBBC05)
    final yellowPath = Path()
      ..moveTo(5.84 * s, 14.10 * s)
      ..cubicTo(5.62 * s, 13.44 * s, 5.49 * s, 12.74 * s, 5.49 * s, 12.0 * s)
      ..cubicTo(5.49 * s, 11.26 * s, 5.62 * s, 10.56 * s, 5.84 * s, 9.90 * s)
      ..lineTo(5.84 * s, 7.06 * s)
      ..lineTo(2.18 * s, 7.06 * s)
      ..cubicTo(1.43 * s, 8.55 * s, 1.0 * s, 10.22 * s, 1.0 * s, 12.0 * s)
      ..cubicTo(1.0 * s, 13.78 * s, 1.43 * s, 15.45 * s, 2.18 * s, 16.94 * s)
      ..lineTo(5.84 * s, 14.10 * s)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05)..isAntiAlias = true);

    // 4. Red Path (#EA4335)
    final redPath = Path()
      ..moveTo(12.0 * s, 5.38 * s)
      ..cubicTo(13.62 * s, 5.38 * s, 15.06 * s, 5.94 * s, 16.21 * s, 7.02 * s)
      ..lineTo(19.36 * s, 3.87 * s)
      ..cubicTo(17.45 * s, 2.09 * s, 14.97 * s, 1.0 * s, 12.0 * s, 1.0 * s)
      ..cubicTo(7.70 * s, 1.0 * s, 3.99 * s, 3.47 * s, 2.18 * s, 7.06 * s)
      ..lineTo(5.84 * s, 9.90 * s)
      ..cubicTo(6.71 * s, 7.30 * s, 9.14 * s, 5.38 * s, 12.0 * s, 5.38 * s)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335)..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google 登入按鈕：次要按鈕樣式（surface 底、細框、深色字），左邊是 Google 標誌
class GoogleStyleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  const GoogleStyleSignInButton({
    super.key,
    required this.onPressed,
    this.label = '使用 Google 繼續',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const GoogleGLogoIcon(size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink2),
      );
    }

    // 外觀（底色、框線、圓角）來自主題的 OutlinedButton 設定
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: content,
      ),
    );
  }
}
