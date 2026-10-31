import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_theme.dart';
import '../../utils/platform_file_helper.dart';
import '../../widgets/custom_toast.dart';
import 'business_card_faces.dart';
import 'profile_editor_state.dart';

/// 下載名片：正面、背面放在同一張圖（上下排），一個檔案就能傳給客戶
/// （2026-10-31 沛沛：一張名片分成兩個檔案給別人感覺不好）
///
/// 先跳出預覽，確認後下載；圖片是名片原尺寸放大 3 倍，夠清楚。
Future<void> showBusinessCardDownload(BuildContext context, BusinessCardData data) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _BusinessCardDownloadDialog(data: data),
  );
}

class _BusinessCardDownloadDialog extends StatefulWidget {
  final BusinessCardData data;

  const _BusinessCardDownloadDialog({required this.data});

  @override
  State<_BusinessCardDownloadDialog> createState() => _BusinessCardDownloadDialogState();
}

class _BusinessCardDownloadDialogState extends State<_BusinessCardDownloadDialog> {
  final GlobalKey _imageKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _download() async {
    setState(() => _isSaving = true);
    try {
      final RenderRepaintBoundary? boundary = _imageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('名片還沒準備好');
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('圖片轉換失敗');
      String name = widget.data.name;
      if (name.isEmpty) name = '我的';
      final String fileName = '${name}_名片.png';
      await PlatformFileHelper.downloadFile(
        bytes: byteData.buffer.asUint8List(),
        fileName: fileName,
        mimeType: 'image/png',
      );
      if (!mounted) return;
      CustomToast.show(context, '已下載 $fileName', ToastType.success);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '下載名片失敗：$error', ToastType.error);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('下載名片', style: AppTextStyles.serif(fontSize: 18, color: colors.ink)),
              const SizedBox(height: 4),
              Text('正面、背面在同一張圖，可以直接傳給客戶', style: TextStyle(fontSize: 12, color: colors.ink3)),
              const SizedBox(height: 14),
              // 下載的就是框起來的這一塊（原尺寸，放大 3 倍輸出）
              FittedBox(
                child: RepaintBoundary(
                  key: _imageKey,
                  child: Container(
                    color: colors.bg,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        BusinessCardFront(data: widget.data),
                        const SizedBox(height: 16),
                        BusinessCardBack(data: widget.data),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _download,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(_isSaving ? '產生圖片中…' : '下載圖片'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
