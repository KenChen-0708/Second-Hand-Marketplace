import 'dart:typed_data';

import 'admin_product_image_cache_service.dart';

class _StubAdminProductImageCacheService
    implements AdminProductImageCacheService {
  @override
  Future<Uint8List?> cacheImage(String? imageUrl) async => null;

  @override
  Future<Uint8List?> getCachedImageBytes(String? imageUrl) async => null;
}

AdminProductImageCacheService createService() =>
    _StubAdminProductImageCacheService();
