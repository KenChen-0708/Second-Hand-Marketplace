import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../services/local/connectivity_service.dart';

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

  static Widget networkImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    IconData placeholderIcon = Icons.image_outlined,
  }) {
    final resolvedUrl = imageUrl?.trim();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _imagePlaceholder(
        width: width,
        height: height,
        icon: placeholderIcon,
      );
    }

    return Image.network(
      resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return _imagePlaceholder(
          width: width,
          height: height,
          icon: placeholderIcon,
          isLoading: true,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _imagePlaceholder(
          width: width,
          height: height,
          icon: placeholderIcon,
        );
      },
    );
  }

  static Widget productImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    final resolvedUrl = resolveProductImageUrl(
      imageUrl,
      fallbackToDefault: false,
    );

    if (resolvedUrl == null) {
      return networkImage(
        defaultProductImageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholderIcon: Icons.image_outlined,
      );
    }

    return Image.network(
      resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return _imagePlaceholder(
          width: width,
          height: height,
          icon: Icons.image_outlined,
          isLoading: true,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return FutureBuilder<bool>(
          future: ConnectivityService.instance.isOnline(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _imagePlaceholder(
                width: width,
                height: height,
                icon: Icons.image_outlined,
                isLoading: true,
              );
            }

            if (snapshot.data == true) {
              return networkImage(
                defaultProductImageUrl,
                fit: fit,
                width: width,
                height: height,
                placeholderIcon: Icons.image_outlined,
              );
            }

            return _imagePlaceholder(
              width: width,
              height: height,
              icon: Icons.image_outlined,
            );
          },
        );
      },
    );
  }

  static Widget avatar(
    String? rawPath, {
    String? name,
    double radius = 20,
    Color? backgroundColor,
  }) {
    final size = radius * 2;
    final trimmedPath = rawPath?.trim();

    if (trimmedPath == null || trimmedPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? const Color(0xFFE2E8F0),
        child: Icon(
          Icons.person_outline_rounded,
          color: const Color(0xFF64748B),
          size: radius,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFFE2E8F0),
      child: ClipOval(
        child: networkImage(
          resolveProfileImageUrl(trimmedPath, name: name),
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholderIcon: Icons.person_outline_rounded,
        ),
      ),
    );
  }

  static Widget _imagePlaceholder({
    double? width,
    double? height,
    IconData icon = Icons.image_outlined,
    bool isLoading = false,
  }) {
    final isCompact =
        (width != null && width <= 36) || (height != null && height <= 36);

    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: isCompact ? 10 : 18,
              height: isCompact ? 10 : 18,
              child: CircularProgressIndicator(
                strokeWidth: isCompact ? 1.4 : 2,
              ),
            )
          else
            Icon(
              icon,
              color: const Color(0xFF9CA3AF),
              size: isCompact ? 16 : 28,
            ),
        ],
      ),
    );
  }
}
