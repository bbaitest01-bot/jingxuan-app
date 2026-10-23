import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 掃描保單第 ② 步：每次掃描前都跳出，勾選「已向客戶說明並取得同意」才能繼續
/// （2026-10-24 沛沛：只在第一次提醒很容易忘記，改成每次都問）
///
/// showPrivacyDetails：第一次使用時多顯示「照片怎麼處理」的完整說明；之後只留勾選與白話說法
/// 回傳 true 代表業務員勾選並按下「開始掃描」
Future<bool> showScanNoticeDialog(
  BuildContext context, {
  required String customerName,
  required bool showPrivacyDetails,
}) async {
  final bool? agreed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _ScanNoticeDialog(
      customerName: customerName,
      showPrivacyDetails: showPrivacyDetails,
    ),
  );
  return agreed ?? false;
}

class _ScanNoticeDialog extends StatefulWidget {
  final String customerName;
  final bool showPrivacyDetails;

  const _ScanNoticeDialog({required this.customerName, required this.showPrivacyDetails});

  @override
  State<_ScanNoticeDialog> createState() => _ScanNoticeDialogState();
}

class _ScanNoticeDialogState extends State<_ScanNoticeDialog> {
  bool _hasCustomerConsent = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String title = '掃描前請先取得同意';
    if (widget.showPrivacyDetails) {
      title = '使用前請先了解';
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(title, style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showPrivacyDetails) ...[
                _PrivacyDetails(colors: colors),
                const SizedBox(height: 10),
              ],
              _CustomerScript(colors: colors),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _hasCustomerConsent,
                onChanged: (bool? checked) => setState(() => _hasCustomerConsent = checked ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 13, color: colors.ink),
                    children: [
                      const TextSpan(text: '已向 '),
                      TextSpan(text: widget.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' 說明並取得同意'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        ElevatedButton(
          onPressed: _hasCustomerConsent ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('開始掃描'),
        ),
      ],
    );
  }
}

/// 第一次使用才顯示：照片怎麼處理、只記錄哪些資料
class _PrivacyDetails extends StatelessWidget {
  final AppColors colors;

  const _PrivacyDetails({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 13, height: 1.6, color: colors.ink2),
        children: [
          const TextSpan(text: '• 照片會送到 AI 辨識保單上的商品，'),
          TextSpan(
            text: '辨識完立即刪除，不會保存',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.ink),
          ),
          const TextSpan(text: '\n• 系統只記錄商品、保額、生效日，不記錄身分證、生日、地址'),
          const TextSpan(text: '\n• 有密碼的電子保單，密碼只在您的裝置上用來開啟檔案，不會傳送或保存'),
          const TextSpan(text: '\n• 每次掃描前，都請先向客戶說明並取得同意'),
        ],
      ),
    );
  }
}

/// 每次都顯示：給客戶的白話說法
class _CustomerScript extends StatelessWidget {
  final AppColors colors;

  const _CustomerScript({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        '可以這樣跟客戶說：「我用系統幫您讀保單上的保障內容，照片不會留存，只記錄您買了哪些保障，方便幫您檢查夠不夠。」',
        style: TextStyle(fontSize: 12, height: 1.6, color: colors.ink2),
      ),
    );
  }
}
