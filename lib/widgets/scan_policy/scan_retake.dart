import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/policy_file_reader.dart';
import '../../services/policy_scan_merge.dart';
import '../../theme/app_theme.dart';

/// 補拍（2026-10-29 D19，組長提出）：不要整張重拍，只拍漏掉或看不清楚的那幾列，再和第一次比對
///
/// 這個檔案放補拍要用的視窗與文字；比對邏輯在 PolicyRetake（policy_scan_merge.dart）

/// 先說明怎麼補拍，再拍照（手機）或上傳照片（電腦）；取消或讀檔失敗回傳 null
Future<Uint8List?> pickRetakePhoto(BuildContext context, {required bool isMobileDevice}) async {
  final bool? shouldContinue = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _RetakeGuideDialog(isMobileDevice: isMobileDevice),
  );
  if (shouldContinue != true) return null;

  Uint8List? bytes;
  String mimeType = 'image/jpeg';
  if (isMobileDevice) {
    final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null) return null;
    bytes = await photo.readAsBytes();
    mimeType = photo.mimeType ?? 'image/jpeg';
  } else {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    bytes = picked.files.first.bytes;
    if ((picked.files.first.extension ?? '').toLowerCase() == 'png') {
      mimeType = 'image/png';
    }
  }
  if (bytes == null) return null;
  final PolicyFileReadResult result = await PolicyFileReader.readImage(bytes, mimeType);
  if (result.status != PolicyFileReadStatus.ok || result.images.isEmpty) return null;
  return result.images.first;
}

/// 補拍的保單號碼或公司不同：問業務員是不是拿錯保單；按「是同一張，繼續」回傳 true
Future<bool> confirmRetakeMismatch(BuildContext context, String mismatchText) async {
  final bool? isSamePolicy = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppColors colors = dialogContext.appColors;
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('這張好像是不同的保單', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        content: Text('$mismatchText。是不是拿錯保單了？', style: TextStyle(fontSize: 13, color: colors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消補拍')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('是同一張，繼續')),
        ],
      );
    },
  );
  return isSamePolicy == true;
}

/// 補拍結果的一句話（給提示訊息用）
String retakeSummaryText(RetakeResult result) {
  final List<String> parts = [];
  if (result.newItems.isNotEmpty) {
    parts.add('補上 ${result.newItems.length} 項');
  }
  if (result.conflicts.isNotEmpty) {
    parts.add('${result.conflicts.length} 項金額或計畫不一樣，請選擇');
  }
  if (parts.isEmpty) {
    return '補拍沒有找到新的項目（${result.duplicateCount} 項和第一次一樣）';
  }
  return '補拍完成：${parts.join('，')}';
}

class _RetakeGuideDialog extends StatelessWidget {
  final bool isMobileDevice;

  const _RetakeGuideDialog({required this.isMobileDevice});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String actionText = '上傳照片';
    if (isMobileDevice) {
      actionText = '拍照';
    }
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('補拍漏掉的部分', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('靠近一點，只拍漏掉或看不清楚的那幾列。', style: TextStyle(fontSize: 13, color: colors.ink)),
          const SizedBox(height: 6),
          Text(
            '剛才讀到的內容會保留；補拍讀到的新項目會加進來，和剛才一樣的會略過，金額不一樣的會讓你選。',
            style: TextStyle(fontSize: 12, color: colors.ink3),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: Text(actionText),
        ),
      ],
    );
  }
}
