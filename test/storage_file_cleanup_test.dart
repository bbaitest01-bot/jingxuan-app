import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/storage_file_cleanup.dart';

void main() {
  group('StorageFileCleanup.storagePathFromPublicUrl', () {
    const String baseUrl = 'https://abc.supabase.co/storage/v1/object/public';

    test('大頭照網址算出「使用者ID/檔名」', () {
      final String? path = StorageFileCleanup.storagePathFromPublicUrl(
        '$baseUrl/avatars/user-1/123.jpg',
        StorageFileCleanup.avatarBucket,
      );
      expect(path, 'user-1/123.jpg');
    });

    test('網址後面的參數不算進路徑', () {
      final String? path = StorageFileCleanup.storagePathFromPublicUrl(
        '$baseUrl/customer-photos/user-1/456.png?t=999',
        StorageFileCleanup.customerPhotoBucket,
      );
      expect(path, 'user-1/456.png');
    });

    test('別的儲存空間、空字串、離線圖片都回傳 null', () {
      expect(
        StorageFileCleanup.storagePathFromPublicUrl('$baseUrl/avatars/user-1/1.jpg', StorageFileCleanup.customerPhotoBucket),
        isNull,
      );
      expect(StorageFileCleanup.storagePathFromPublicUrl('', StorageFileCleanup.avatarBucket), isNull);
      expect(
        StorageFileCleanup.storagePathFromPublicUrl('data:image/jpeg;base64,AAAA', StorageFileCleanup.avatarBucket),
        isNull,
      );
    });
  });
}
