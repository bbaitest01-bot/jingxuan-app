import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 用 Storage API 刪掉不再使用的照片（全景地圖 4-O）。
/// Supabase 不准用 SQL 直接刪照片，所以「換照片、永久刪除客戶」後由 App 自己清舊檔。
/// 一律在資料存成功之後才呼叫；刪不掉只記錄、不丟例外，不影響使用者操作。
class StorageFileCleanup {
  static const String avatarBucket = 'avatars';
  static const String customerPhotoBucket = 'customer-photos';

  /// 從公開網址算出儲存路徑；不是這個儲存空間的網址（或是空字串、離線用的 data: 圖片）回傳 null。
  /// 例：https://xxx.supabase.co/storage/v1/object/public/avatars/使用者ID/123.jpg → 使用者ID/123.jpg
  static String? storagePathFromPublicUrl(String publicUrl, String bucket) {
    final String marker = '/$bucket/';
    final int markerIndex = publicUrl.indexOf(marker);
    if (markerIndex == -1) return null;

    String path = publicUrl.substring(markerIndex + marker.length);
    // 網址後面可能帶 ?t=... 這類參數
    final int queryIndex = path.indexOf('?');
    if (queryIndex != -1) path = path.substring(0, queryIndex);
    path = Uri.decodeComponent(path);
    if (path.isEmpty) return null;
    return path;
  }

  /// 照片換掉或清除時，刪掉舊照片；沒換（網址一樣）就什麼都不做
  static Future<void> removeReplacedFile({
    required String oldPublicUrl,
    required String newPublicUrl,
    required String bucket,
  }) async {
    if (oldPublicUrl.isEmpty || oldPublicUrl == newPublicUrl) return;
    await removeFile(publicUrl: oldPublicUrl, bucket: bucket);
  }

  /// 刪掉一張照片；只刪登入者自己資料夾裡的檔案（Storage 權限也只允許刪自己的）
  static Future<void> removeFile({required String publicUrl, required String bucket}) async {
    final String? storagePath = storagePathFromPublicUrl(publicUrl, bucket);
    if (storagePath == null) return;

    final SupabaseClient supabase = Supabase.instance.client;
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null || !storagePath.startsWith('$userId/')) return;

    try {
      await supabase.storage.from(bucket).remove([storagePath]);
    } catch (error) {
      debugPrint('刪除舊照片失敗（$bucket/$storagePath）: $error');
    }
  }
}
