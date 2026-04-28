import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/local/admin_product_image_cache_service.dart';

class AdminCachedProductImage extends StatefulWidget {
  const AdminCachedProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<AdminCachedProductImage> createState() => _AdminCachedProductImageState();
}

class _AdminCachedProductImageState extends State<AdminCachedProductImage> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCachedImage());
  }

  @override
  void didUpdateWidget(covariant AdminCachedProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _cachedBytes = null;
      unawaited(_loadCachedImage());
    }
  }

  Future<void> _loadCachedImage() async {
    final cachedBytes = await AdminProductImageCacheService.instance
        .getCachedImageBytes(widget.imageUrl);

    if (cachedBytes != null && mounted) {
      setState(() => _cachedBytes = cachedBytes);
    }

    final refreshedBytes = await AdminProductImageCacheService.instance
        .cacheImage(widget.imageUrl);

    if (!mounted || refreshedBytes == null) {
      return;
    }

    if (!listEquals(_cachedBytes, refreshedBytes)) {
      setState(() => _cachedBytes = refreshedBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    final borderRadius = widget.borderRadius;
    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(borderRadius: borderRadius, child: image);
  }

  Widget _buildImage() {
    if (_cachedBytes != null) {
      return Image.memory(
        _cachedBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildNetworkImage(),
      );
    }

    return _buildNetworkImage();
  }

  Widget _buildNetworkImage() {
    final imageUrl = widget.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return _placeholder(isLoading: true);
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder({bool isLoading = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.image_rounded,
              size: 64,
              color: Colors.black26,
            ),
    );
  }
}
