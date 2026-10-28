import 'dart:typed_data';

import 'policy_file_reader_stub.dart'
    if (dart.library.js_interop) 'policy_file_reader_web.dart' as implementation;

/// 讀檔的結果狀態
enum PolicyFileReadStatus { ok, needPassword, wrongPassword, noText, error }

/// 電子保單 PDF、截圖轉成 JPEG 的結果（images 是每一頁的 JPEG 檔案內容）
class PolicyFileReadResult {
  final PolicyFileReadStatus status;
  final List<Uint8List> images;
  final int pageCount;
  // readPdfText() 才有：PDF 裡的文字（個資已在本機遮蔽）
  final String text;
  // 失敗原因（例：decode_failed、exception 4032x3024 …）；只記技術原因，不含保單內容
  final String failureReason;

  const PolicyFileReadResult({
    required this.status,
    this.images = const [],
    this.pageCount = 0,
    this.text = '',
    this.failureReason = '',
  });
}

/// 掃描保單：在瀏覽器裡把電子保單、截圖轉成要送去辨識的圖片（實際做法在 web/policy_file_reader.js）
///
/// PDF 的密碼只在這台裝置上用來打開檔案，不會傳出去、也不會保存。
class PolicyFileReader {
  /// PDF → 前幾頁的圖片；有密碼時第一次回傳 needPassword，帶密碼再呼叫一次
  static Future<PolicyFileReadResult> readPdf(Uint8List bytes, {String password = ''}) {
    return implementation.readPdfImpl(bytes, password);
  }

  /// 截圖、照片 → 縮小並轉成 JPEG
  static Future<PolicyFileReadResult> readImage(Uint8List bytes, String mimeType) {
    return implementation.readImageImpl(bytes, mimeType);
  }

  /// 電子保單 PDF → 直接取出文字（不轉圖片）；個資在本機先遮蔽。
  /// PDF 其實是掃描圖片、沒有文字時回傳 noText，畫面改用圖片辨識
  static Future<PolicyFileReadResult> readPdfText(Uint8List bytes, {String password = ''}) {
    return implementation.readPdfTextImpl(bytes, password);
  }

  /// 照片切成上下兩半（中間重疊），讓 AI 看得更清楚
  static Future<PolicyFileReadResult> splitImage(Uint8List bytes) {
    return implementation.splitImageImpl(bytes);
  }
}
