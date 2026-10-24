import 'dart:typed_data';

import 'policy_file_reader.dart';

// 非網頁環境（測試、手機原生）：不支援 PDF；圖片原封不動回傳
Future<PolicyFileReadResult> readPdfImpl(Uint8List bytes, String password) async {
  return const PolicyFileReadResult(status: PolicyFileReadStatus.error);
}

Future<PolicyFileReadResult> readImageImpl(Uint8List bytes, String mimeType) async {
  return PolicyFileReadResult(status: PolicyFileReadStatus.ok, images: [bytes], pageCount: 1);
}

Future<PolicyFileReadResult> readPdfTextImpl(Uint8List bytes, String password) async {
  return const PolicyFileReadResult(status: PolicyFileReadStatus.error);
}

Future<PolicyFileReadResult> splitImageImpl(Uint8List bytes) async {
  return PolicyFileReadResult(status: PolicyFileReadStatus.ok, images: [bytes], pageCount: 1);
}
