import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static const String productImageBucket = 'product_images';
  static const String defaultProductImageUrl =
      'https://yqvgeownycvbzelukmfp.supabase.co/storage/v1/object/public/product_images/default.png';

  static String productOrDefault(String? imageUrl) {
    return resolveProductImageUrl(imageUrl) ?? defaultProductImageUrl;
  }

  static String? resolveProductImageUrl(
    String? rawPath, {
    bool fallbackToDefault = true,
  }) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return fallbackToDefault ? defaultProductImageUrl : null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = _normalizeProductImagePath(path);
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return fallbackToDefault ? defaultProductImageUrl : null;
    }

    return Supabase.instance.client.storage
        .from(productImageBucket)
        .getPublicUrl(normalizedPath);
  }

  static List<String> resolveProductImageUrls(dynamic rawImages) {
    if (rawImages is! List) {
      return const [];
    }

    return rawImages
        .map(
          (image) => resolveProductImageUrl(
            image?.toString(),
            fallbackToDefault: false,
          ),
        )
        .whereType<String>()
        .toList();
  }

  static String? _normalizeProductImagePath(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }

    normalized = normalized.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    const publicPrefix = 'storage/v1/object/public/$productImageBucket/';
    if (normalized.startsWith(publicPrefix)) {
      return normalized.substring(publicPrefix.length);
    }

    const bucketPrefix = '$productImageBucket/';
    if (normalized.startsWith(bucketPrefix)) {
      return normalized.substring(bucketPrefix.length);
    }

    return normalized;
  }
}
