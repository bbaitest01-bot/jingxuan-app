import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'policy_file_reader.dart';

// 對應 web/policy_file_reader.js 裡掛在 window 上的兩個函式；結果是 JSON 字串
@JS('jingxuanPdfToImages')
external JSPromise<JSString> _pdfToImages(JSUint8Array bytes, JSString password);

@JS('jingxuanImageToJpeg')
external JSPromise<JSString> _imageToJpeg(JSUint8Array bytes, JSString mimeType);

Future<PolicyFileReadResult> readPdfImpl(Uint8List bytes, String password) async {
  try {
    final JSString result = await _pdfToImages(bytes.toJS, password.toJS).toDart;
    return _parseResult(result.toDart);
  } catch (error) {
    return const PolicyFileReadResult(status: PolicyFileReadStatus.error);
  }
}

Future<PolicyFileReadResult> readImageImpl(Uint8List bytes, String mimeType) async {
  try {
    final JSString result = await _imageToJpeg(bytes.toJS, mimeType.toJS).toDart;
    return _parseResult(result.toDart);
  } catch (error) {
    return const PolicyFileReadResult(status: PolicyFileReadStatus.error);
  }
}

PolicyFileReadResult _parseResult(String jsonText) {
  final Map<String, dynamic> data = jsonDecode(jsonText) as Map<String, dynamic>;
  final String status = data['status']?.toString() ?? 'error';
  if (status == 'need_password') {
    return const PolicyFileReadResult(status: PolicyFileReadStatus.needPassword);
  }
  if (status == 'wrong_password') {
    return const PolicyFileReadResult(status: PolicyFileReadStatus.wrongPassword);
  }
  if (status != 'ok') {
    return const PolicyFileReadResult(status: PolicyFileReadStatus.error);
  }

  final List<Uint8List> images = [];
  final List<dynamic> rawImages = data['images'] is List ? data['images'] as List : const [];
  for (final dynamic rawImage in rawImages) {
    images.add(base64Decode(rawImage.toString()));
  }
  final int pageCount = (data['pageCount'] as num?)?.toInt() ?? images.length;
  return PolicyFileReadResult(status: PolicyFileReadStatus.ok, images: images, pageCount: pageCount);
}
