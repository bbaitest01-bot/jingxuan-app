
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/customer_policy_service.dart';
import '../../services/customer_service.dart';
import '../../services/policy_file_reader.dart';
import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import 'scan_capture_panel.dart';
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
    while (result.status == PolicyFileReadStatus.needPassword ||
        result.status == PolicyFileReadStatus.wrongPassword) {
      if (!mounted) return;
      final String? password = await showPdfPasswordDialog(
        context,
        showWrongPasswordHint: result.status == PolicyFileReadStatus.wrongPassword,
      );
      if (password == null) return;
      result = await PolicyFileReader.readPdf(bytes, password: password);
    }
    _addImages(result);
    if (result.status == PolicyFileReadStatus.ok && result.pageCount > maximumImageCount && mounted) {
      CustomToast.show(context, '這份 PDF 有 ${result.pageCount} 頁，先取前 $maximumImageCount 頁；不需要的頁面可以移除', ToastType.warning);
    }
  }

  void _addImages(PolicyFileReadResult result) {
    if (!mounted) return;
    if (result.status != PolicyFileReadStatus.ok || result.images.isEmpty) {
      CustomToast.show(context, '檔案讀取失敗，請換一個檔案或改用截圖', ToastType.error);
      return;
    }
    setState(() {
      for (final Uint8List image in result.images) {
        if (_remainingSlots <= 0) break;
        _images.add(image);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 辨識
  // ---------------------------------------------------------------------------
  Future<void> _recognize() async {
    setState(() => _step = _ScanStep.recognizing);
    final List<PolicyScanImage> scanImages = [];
    for (final Uint8List image in _images) {
      scanImages.add(PolicyScanImage(bytes: image, mimeType: 'image/jpeg'));
    }

    try {
      final ScannedPolicy policy = await _scanService.recognizePolicy(scanImages);
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

  void _removeItem(int index) {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    setState(() => policy.items.removeAt(index));
  }

  Future<void> _save() async {
    final ScannedPolicy? policy = _scannedPolicy;
    if (policy == null) return;
    setState(() => _isSaving = true);

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
        onAddItem: _addItem,
        onStatusChanged: (String status) => setState(() => _status = status),
        onRescan: _rescan,
        onSave: _save,
      );
    }
    if (_step == _ScanStep.recognizing) {
      return _RecognizingIndicator(colors: colors);
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
          onRemoveImage: (int index) => setState(() => _images.removeAt(index)),
          onStartRecognize: _recognize,
        ),
      ],
    );
  }
}

class _RecognizingIndicator extends StatelessWidget {
  final AppColors colors;

  const _RecognizingIndicator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          CircularProgressIndicator(color: colors.acc),
          const SizedBox(height: 16),
          Text('AI 辨識中，通常幾秒鐘就好…', style: TextStyle(fontSize: 13, color: colors.ink2)),
          const SizedBox(height: 4),
          Text('辨識完照片就會刪除', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ],
      ),
    );
  }
}
