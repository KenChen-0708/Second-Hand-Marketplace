import 'dart:typed_data';

import 'admin_product_image_cache_service_stub.dart'
    if (dart.library.io) 'admin_product_image_cache_service_io.dart' as impl;

abstract class AdminProductImageCacheService {
  static final AdminProductImageCacheService instance = impl.createService();

  Future<Uint8List?> getCachedImageBytes(String? imageUrl);

  Future<Uint8List?> cacheImage(String? imageUrl);
}
