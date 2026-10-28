import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 掃描保單第 ③ 步：取得保單影像
///
/// 手機、平板：拍照（紙本）＋上傳檔案（電子保單 PDF、截圖）
/// 電腦：只有上傳檔案，並提醒紙本請用手機開啟本頁拍照（2026-10-24 沛沛確認）
class ScanCapturePanel extends StatelessWidget {
  final bool isMobileDevice;
  final List<Uint8List> images;
  final int maximumImageCount;
  // 電子保單有文字：會直接讀文字（畫面提示「更準確」）
  final bool isReadingPdfText;
  final VoidCallback onTakePhoto;
  final VoidCallback onUploadFile;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onStartRecognize;

  const ScanCapturePanel({
    super.key,
    required this.isMobileDevice,
    required this.images,
    required this.maximumImageCount,
    this.isReadingPdfText = false,
    required this.onTakePhoto,
    required this.onUploadFile,
    required this.onRemoveImage,
    required this.onStartRecognize,
  });

  bool get _canAddMore => images.length < maximumImageCount;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('只要拍 1 張：列出主約、附約的那一頁', style: TextStyle(fontSize: 13, color: colors.ink2)),
        const SizedBox(height: 2),
        Text('封面、條款說明頁不用拍；保單號碼不在這頁的話，辨識後可以自己補上', style: TextStyle(fontSize: 12, color: colors.ink3)),
        const SizedBox(height: 12),
        _buildSourceButtons(colors),
        if (!isMobileDevice) ...[
          const SizedBox(height: 10),
          _PaperPolicyHint(colors: colors),
        ],
        if (images.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '已選 ${images.length}/$maximumImageCount 張',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
          ),
          const SizedBox(height: 8),
          _buildThumbnails(colors),
          // 照片拍了 2 張以上：AI 要分次看，可能要等比較久（2026-10-29 Groq 每分鐘用量上限）
          if (images.length > 1 && !isReadingPdfText) ...[
            const SizedBox(height: 8),
            Text(
              '拍了 ${images.length} 張，AI 要一張一張看，可能要等 20～40 秒；只留主約、附約那一頁會比較快',
              style: TextStyle(fontSize: 12, color: colors.warn),
            ),
          ],
          if (isReadingPdfText) ...[
            const SizedBox(height: 8),
            _PdfTextHint(colors: colors),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStartRecognize,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('開始辨識'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceButtons(AppColors colors) {
    final List<Widget> buttons = [];
    if (isMobileDevice) {
      buttons.add(Expanded(
        child: _SourceButton(
          icon: Icons.photo_camera_outlined,
          title: images.isEmpty ? '拍照' : '再拍一張',
          subtitle: '紙本保單',
          isEnabled: _canAddMore,
          onPressed: onTakePhoto,
        ),
      ));
      buttons.add(const SizedBox(width: 10));
    }
    buttons.add(Expanded(
      child: _SourceButton(
        icon: Icons.upload_file_outlined,
        title: '上傳檔案',
        subtitle: '電子保單 PDF、截圖',
        isEnabled: _canAddMore,
        onPressed: onUploadFile,
      ),
    ));
    return Row(children: buttons);
  }

  Widget _buildThumbnails(AppColors colors) {
    final List<Widget> thumbnails = [];
    for (int index = 0; index < images.length; index++) {
      thumbnails.add(_ImageThumbnail(
        imageBytes: images[index],
        pageNumber: index + 1,
        onRemove: () => onRemoveImage(index),
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: thumbnails);
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final VoidCallback onPressed;

  const _SourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color iconColor = colors.acc;
    if (!isEnabled) {
      iconColor = colors.ink3;
    }
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 26, color: iconColor),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: colors.ink3), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// 電腦版提醒：紙本保單請改用手機或平板
class _PaperPolicyHint extends StatelessWidget {
  final AppColors colors;

  const _PaperPolicyHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.accSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone_outlined, size: 16, color: colors.acc),
          const SizedBox(width: 8),
          Expanded(
            child: Text('紙本保單請用手機或平板開啟本頁拍照', style: TextStyle(fontSize: 12, color: colors.acc)),
          ),
        ],
      ),
    );
  }
}

/// 電子保單提示：直接讀文字、個資先遮蔽
class _PdfTextHint extends StatelessWidget {
  final AppColors colors;

  const _PdfTextHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.text_snippet_outlined, size: 16, color: colors.ok),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '電子保單：直接讀取文字（較準確），身分證、電話等個資會先在本機遮蔽',
            style: TextStyle(fontSize: 12, color: colors.ok),
          ),
        ),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final Uint8List imageBytes;
  final int pageNumber;
  final VoidCallback onRemove;

  const _ImageThumbnail({required this.imageBytes, required this.pageNumber, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Stack(
      children: [
        Container(
          width: 96,
          height: 128,
          decoration: BoxDecoration(
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(imageBytes, fit: BoxFit.cover),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text('$pageNumber', style: AppTextStyles.mono(fontSize: 11, color: colors.ink)),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: '移除這張',
            style: IconButton.styleFrom(backgroundColor: colors.surface, foregroundColor: colors.ink),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
