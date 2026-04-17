import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class ImageHelper {
  static const String productImageBucket = 'product_images';
  static const String profileImageBucket = 'profile_images';
  
  static const String defaultProductImageUrl =
      'https://yqvgeownycvbzelukmfp.supabase.co/storage/v1/object/public/product_images/default.png';
  
  static String getDefaultAvatarUrl(String? name) {
    final displayName = (name == null || name.isEmpty) ? 'User' : Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$displayName&background=cbd5e1&color=fff';
  }

  static String resolveProfileImageUrl(String? rawPath, {String? name}) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return getDefaultAvatarUrl(name);
    }
    
    if (path.startsWith('http')) return path;

    // Get the public URL from Supabase
    final String publicUrl = Supabase.instance.client.storage
        .from(profileImageBucket)
        .getPublicUrl(path);
    
    // Add cache buster
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Uploads profile image bytes to Supabase Storage.
  static Future<String?> uploadProfileImage(Uint8List bytes, String userId, String mimeType) async {
    final extension = mimeType.split('/').last;
    final fileName = 'avatar_$userId.$extension';
    try {
      await Supabase.instance.client.storage
          .from(profileImageBucket)
          .uploadBinary(
            fileName, 
            bytes, 
            fileOptions: FileOptions(
              upsert: true, 
              contentType: mimeType
            )
          );
      return fileName;
    } catch (e) {
      debugPrint('Supabase Upload Error: $e');
      rethrow;
    }
  }

  static String productOrDefault(String? imageUrl) {
    return resolveProductImageUrl(imageUrl) ?? defaultProductImageUrl;
  }

  static String? resolveProductImageUrl(String? rawPath, {bool fallbackToDefault = true}) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) return fallbackToDefault ? defaultProductImageUrl : null;
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from(productImageBucket).getPublicUrl(path);
  }

  static List<String> resolveProductImageUrls(dynamic rawImages) {
    if (rawImages is! List) return const [];
    return rawImages
        .map((image) => resolveProductImageUrl(image?.toString(), fallbackToDefault: false))
        .whereType<String>()
        .toList();
  }

  static Widget productImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return Image.network(
      productOrDefault(imageUrl),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(defaultProductImageUrl, fit: fit, width: width, height: height);
      },
    );
  }

  static Widget _imagePlaceholder({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}
