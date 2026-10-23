import 'dart:typed_data';

import 'policy_file_reader_stub.dart'
    if (dart.library.js_interop) 'policy_file_reader_web.dart' as implementation;

/// 讀檔的結果狀態
enum PolicyFileReadStatus { ok, needPassword, wrongPassword, error }

/// 電子保單 PDF、截圖轉成 JPEG 的結果（images 是每一頁的 JPEG 檔案內容）
class PolicyFileReadResult {
  final PolicyFileReadStatus status;
  final List<Uint8List> images;
  final int pageCount;

  const PolicyFileReadResult({required this.status, this.images = const [], this.pageCount = 0});
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
}
