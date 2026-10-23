import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 電子保單有密碼時跳出來的輸入框；回傳輸入的密碼，按取消回傳 null
/// showWrongPasswordHint：上一次密碼錯誤時顯示紅字提醒
Future<String?> showPdfPasswordDialog(BuildContext context, {required bool showWrongPasswordHint}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _PdfPasswordDialog(showWrongPasswordHint: showWrongPasswordHint),
  );
}

class _PdfPasswordDialog extends StatefulWidget {
  final bool showWrongPasswordHint;

  const _PdfPasswordDialog({required this.showWrongPasswordHint});

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordHidden = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final String password = _passwordController.text.trim();
    if (password.isEmpty) {
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: colors.acc),
          const SizedBox(width: 8),
          Text('這份保單有密碼', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('請輸入開啟密碼（通常是被保險人身分證字號）', style: TextStyle(fontSize: 13, color: colors.ink2)),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              autofocus: true,
              obscureText: _isPasswordHidden,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '密碼',
                errorText: widget.showWrongPasswordHint ? '密碼不正確，請再試一次' : null,
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  tooltip: _isPasswordHidden ? '顯示密碼' : '隱藏密碼',
                  onPressed: () => setState(() => _isPasswordHidden = !_isPasswordHidden),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: colors.ink3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '密碼只在這台裝置上用來打開檔案，不會上傳、不會保存。',
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('開啟'),
        ),
      ],
    );
  }
}
