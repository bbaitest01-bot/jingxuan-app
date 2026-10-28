
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/customer_policy_service.dart';
import '../../services/customer_service.dart';
import '../../services/policy_file_reader.dart';
import '../../services/policy_scan_merge.dart';
import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import 'scan_capture_panel.dart';
import 'scan_duplicate_dialog.dart';
import 'scan_item_edit_dialog.dart';
import 'scan_pdf_password_dialog.dart';
import 'scan_review_panel.dart';

/// 掃描畫面目前在哪一步
enum _ScanStep { capture, recognizing, review }

/// 掃描保單主畫面：③ 取得影像 → 辨識中 → ④ 確認存入
///
/// customerId 是 null 代表「當場新增的客戶」，按下存入時才真的建立，
/// 這樣中途取消就不會多出一位空白客戶。存入成功時 pop(true)。
class ScanPolicyScreen extends StatefulWidget {
  final String? customerId;
  final String customerName;

  const ScanPolicyScreen({super.key, required this.customerId, required this.customerName});

  @override
  State<ScanPolicyScreen> createState() => _ScanPolicyScreenState();
}

class _ScanPolicyScreenState extends State<ScanPolicyScreen> {
  static const int maximumImageCount = 3;

  final PolicyScanService _scanService = PolicyScanService();
  // 影像只放在記憶體裡，離開這個畫面就消失，不會存到任何地方
  final List<Uint8List> _images = [];
  // 好幾張照片分開辨識時，目前辨識到第幾張（畫面顯示「第 1／2 張」）
  int _recognizingPhotoNumber = 0;
  // 電子保單 PDF 取出的文字（個資已遮蔽）；有文字就送文字、不送圖片（2026-10-25 B 做法）
  String? _pdfText;
  _ScanStep _step = _ScanStep.capture;
  ScannedPolicy? _scannedPolicy;
  String _status = PolicyStatus.active;
  bool _isSaving = false;

  bool get _isMobileDevice {
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  int get _remainingSlots => maximumImageCount - _images.length;

  // ---------------------------------------------------------------------------
  // ③ 取得影像
  // ---------------------------------------------------------------------------
  Future<void> _takePhoto() async {
    final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null) return;
    final Uint8List bytes = await photo.readAsBytes();
    final PolicyFileReadResult result = await PolicyFileReader.readImage(bytes, photo.mimeType ?? 'image/jpeg');
    _addImages(result);
  }

  Future<void> _uploadFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final PlatformFile file = picked.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    final String extension = (file.extension ?? '').toLowerCase();
    if (extension == 'pdf') {
      await _readPdf(bytes);
      return;
    }
    String mimeType = 'image/jpeg';
    if (extension == 'png') {
      mimeType = 'image/png';
    }
    final PolicyFileReadResult result = await PolicyFileReader.readImage(bytes, mimeType);
    _addImages(result);
  }

  /// 打開 PDF；有密碼就請業務員輸入，密碼錯了再問一次，按取消就放棄
  Future<void> _readPdf(Uint8List bytes) async {
    PolicyFileReadResult result = await PolicyFileReader.readPdf(bytes);
    String password = '';
    while (result.status == PolicyFileReadStatus.needPassword ||
        result.status == PolicyFileReadStatus.wrongPassword) {
      if (!mounted) return;
      final String? typedPassword = await showPdfPasswordDialog(
        context,
        showWrongPasswordHint: result.status == PolicyFileReadStatus.wrongPassword,
      );
      if (typedPassword == null) return;
      password = typedPassword;
      result = await PolicyFileReader.readPdf(bytes, password: password);
    }
    // 圖片給業務員看縮圖；文字（有的話）才是送給 AI 的內容。掃描成圖片的 PDF 沒有文字，就送圖片
    String? pdfText;
    if (result.status == PolicyFileReadStatus.ok) {
      final PolicyFileReadResult textResult = await PolicyFileReader.readPdfText(bytes, password: password);
      if (textResult.status == PolicyFileReadStatus.ok) {
        pdfText = textResult.text;
      }
    }
    _addImages(result, pdfText: pdfText);
    if (result.status == PolicyFileReadStatus.ok && result.pageCount > maximumImageCount && mounted) {
      CustomToast.show(context, '這份 PDF 有 ${result.pageCount} 頁，先取前 $maximumImageCount 頁；不需要的頁面可以移除', ToastType.warning);
    }
  }

  /// pdfText：這批圖片來自有文字的電子保單；只有「一開始就是這份 PDF」時才用文字，混了照片就改送圖片
  void _addImages(PolicyFileReadResult result, {String? pdfText}) {
    if (!mounted) return;
    if (result.status != PolicyFileReadStatus.ok || result.images.isEmpty) {
      CustomToast.show(context, '檔案讀取失敗，請換一個檔案或改用截圖', ToastType.error);
      return;
    }
    setState(() {
      if (pdfText != null && _images.isEmpty) {
        _pdfText = pdfText;
      } else {
        _pdfText = null;
      }
      for (final Uint8List image in result.images) {
        if (_remainingSlots <= 0) break;
        _images.add(image);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 辨識
  // ---------------------------------------------------------------------------
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) {
        _pdfText = null;
      }
    });
  }

  /// 選送給 AI 的內容：電子保單文字 → 一張照片切上下兩半 → 多張照片原樣
  Future<ScannedPolicy> _recognizeSelectedContent() async {
    final String? pdfText = _pdfText;
    if (pdfText != null) {
      return _scanService.recognizePolicyText(pdfText);
    }
    // 每張照片各自切兩半、分開辨識，再合成一份（2026-10-29 做法 A：封面＋條款頁兩張時原本整張送，容易漏項）
    // 一張一張依序送，不同時送，避免碰到 Groq 每分鐘上限
    // 封面這類沒有商品的頁面不算失敗；全部都沒有商品才提示
    final bool hasSeveralPhotos = _images.length > 1;
    final List<ScannedPolicy> pages = [];
    for (int index = 0; index < _images.length; index++) {
      if (mounted) setState(() => _recognizingPhotoNumber = index + 1);
      pages.add(await _recognizePhoto(_images[index], allowNoItems: hasSeveralPhotos));
    }
    if (pages.length == 1) {
      return pages.first;
    }
    final ScannedPolicy merged = PolicyScanMerge.mergePages(pages);
    if (merged.items.isEmpty) {
      throw const PolicyScanException(PolicyScanService.noItemsMessage);
    }
    return merged;
  }

  /// 一張照片：切成上下兩半辨識；切不了就整張送，並把原因記到雲端函式 Logs
  Future<ScannedPolicy> _recognizePhoto(Uint8List photo, {required bool allowNoItems}) async {
    final PolicyFileReadResult splitResult = await PolicyFileReader.splitImage(photo);
    if (splitResult.status == PolicyFileReadStatus.ok && splitResult.images.length == 2) {
      final List<PolicyScanImage> halves = [];
      for (final Uint8List half in splitResult.images) {
        halves.add(PolicyScanImage(bytes: half, mimeType: 'image/jpeg'));
      }
      return _scanService.recognizePolicy(halves, isSplitImage: true, allowNoItems: allowNoItems);
    }
    final String splitFailureReason =
        'split_${splitResult.status.name} ${splitResult.failureReason} images=${splitResult.images.length}';
    return _scanService.recognizePolicy(
      [PolicyScanImage(bytes: photo, mimeType: 'image/jpeg')],
      splitFailureReason: splitFailureReason,
      allowNoItems: allowNoItems,
    );
  }

  Future<void> _recognize() async {
    setState(() => _step = _ScanStep.recognizing);
    try {
      final ScannedPolicy policy = await _recognizeSelectedContent();
      await _scanService.matchCatalog(policy);
      if (!mounted) return;
      setState(() {
        _scannedPolicy = policy;
        _step = _ScanStep.review;
      });
    } on PolicyScanException catch (error) {
      if (!mounted) return;
      setState(() => _step = _ScanStep.capture);
      CustomToast.show(context, error.message, ToastType.error);
    }
  }

  void _rescan() {
    setState(() {
      _images.clear();
      _pdfText = null;
      _scannedPolicy = null;
      _step = _ScanStep.capture;
    });
  }

  // ---------------------------------------------------------------------------
  // ④ 確認、修改、存入
  // ---------------------------------------------------------------------------
  Future<void> _editItem(int index) async {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    final ScannedPolicyItem? edited = await showScanItemEditDialog(
      context,
      item: policy.items[index],
      companyShortName: PolicyScanService.companyShortNames[policy.companyCode],
      isNewItem: false,
    );
    if (edited == null) return;
    setState(() => policy.items[index] = edited);
  }

  Future<void> _addItem() async {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    final ScannedPolicyItem? added = await showScanItemEditDialog(
      context,
      item: ScannedPolicyItem(productName: '', coverageRole: 'rider'),
      companyShortName: PolicyScanService.companyShortNames[policy.companyCode],
      isNewItem: true,
    );
    if (added == null) return;
    setState(() => policy.items.add(added));
  }

  void _applySuggestion(int index) {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    setState(() => policy.items[index].applySuggestion());
  }

  /// 這位客戶已經存過同一個保單號碼時，先問業務員要不要再存（新客戶不用查）
  Future<bool> _confirmIfDuplicate(ScannedPolicy policy) async {
    final String? customerId = widget.customerId;
    final String policyNumber = policy.policyNumber ?? '';
    if (customerId == null || policyNumber.isEmpty) {
      return true;
    }
    final ExistingPolicyInfo? existingPolicy = await _scanService.findExistingPolicy(
      customerId: customerId,
      policyNumber: policyNumber,
    );
    if (existingPolicy == null || !mounted) {
      return true;
    }
    return showScanDuplicateDialog(
      context,
      customerName: widget.customerName,
      policyNumber: policyNumber,
      existingPolicy: existingPolicy,
    );
  }

  void _removeItem(int index) {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    setState(() => policy.items.removeAt(index));
  }

  Future<void> _save() async {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    setState(() => _isSaving = true);
    final bool shouldSave = await _confirmIfDuplicate(policy);
    if (!shouldSave) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      // 當場新增的客戶，到這一步才建立
      String? customerId = widget.customerId;
      customerId ??= await CustomerService.instance.createCustomerWithName(widget.customerName);
      await _scanService.saveScannedPolicy(customerId: customerId, policy: policy, status: _status);
      if (!mounted) return;
      CustomToast.show(context, '已存入 ${widget.customerName} 的保單（${policy.items.length} 項）', ToastType.success);
      Navigator.pop(context, true);
    } on PolicyScanException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, error.message, ToastType.error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '存入失敗，請檢查網路後再試', ToastType.error);
    }
  }

  // ---------------------------------------------------------------------------
  // 畫面
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String title = '掃描保單';
    if (_step == _ScanStep.review) {
      title = '確認辨識結果';
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(title, style: AppTextStyles.serif(fontSize: 17, color: colors.ink)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [_buildStepContent(colors)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(AppColors colors) {
    final ScannedPolicy? policy = _scannedPolicy;
    if (_step == _ScanStep.review && policy != null) {
      return ScanReviewPanel(
        customerName: widget.customerName,
        policy: policy,
        status: _status,
        isSaving: _isSaving,
        onEditItem: _editItem,
        onRemoveItem: _removeItem,
        onApplySuggestion: _applySuggestion,
        onAddItem: _addItem,
        onStatusChanged: (String status) => setState(() => _status = status),
        onRescan: _rescan,
        onSave: _save,
      );
    }
    if (_step == _ScanStep.recognizing) {
      String progressText = 'AI 辨識中，通常幾秒鐘就好…';
      if (_images.length > 1 && _pdfText == null) {
        progressText = 'AI 辨識中（第 $_recognizingPhotoNumber／${_images.length} 張）…';
      }
      return _RecognizingIndicator(colors: colors, progressText: progressText);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('客戶：${widget.customerName}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
        const SizedBox(height: 8),
        ScanCapturePanel(
          isMobileDevice: _isMobileDevice,
          images: _images,
          maximumImageCount: maximumImageCount,
          onTakePhoto: _takePhoto,
          onUploadFile: _uploadFile,
          isReadingPdfText: _pdfText != null,
          onRemoveImage: _removeImage,
          onStartRecognize: _recognize,
        ),
      ],
    );
  }
}

class _RecognizingIndicator extends StatelessWidget {
  final AppColors colors;
  final String progressText;

  const _RecognizingIndicator({required this.colors, required this.progressText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          CircularProgressIndicator(color: colors.acc),
          const SizedBox(height: 16),
          Text(progressText, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.ink2)),
          const SizedBox(height: 4),
          Text('辨識完照片就會刪除', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ],
      ),
    );
  }
}
