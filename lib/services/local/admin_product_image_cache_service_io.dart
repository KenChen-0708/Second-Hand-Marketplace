import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'admin_product_image_cache_service.dart';

class _IoAdminProductImageCacheService
    implements AdminProductImageCacheService {
  static const String _cacheFolderName = 'admin_product_image_cache';
  static const Duration _maxCacheAge = Duration(days: 7);

  final Map<String, Future<Uint8List?>> _inFlightDownloads = {};

  @override
  Future<Uint8List?> getCachedImageBytes(String? imageUrl) async {
    final normalizedUrl = _normalizeUrl(imageUrl);
    if (normalizedUrl == null) {
      return null;
    }

    final file = await _fileForUrl(normalizedUrl);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  @override
  Future<Uint8List?> cacheImage(String? imageUrl) async {
    final normalizedUrl = _normalizeUrl(imageUrl);
    if (normalizedUrl == null) {
      return null;
    }

    final existingFuture = _inFlightDownloads[normalizedUrl];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _cacheImageInternal(normalizedUrl);
    _inFlightDownloads[normalizedUrl] = future;

    try {
      return await future;
    } finally {
      _inFlightDownloads.remove(normalizedUrl);
    }
  }

  Future<Uint8List?> _cacheImageInternal(String imageUrl) async {
    final file = await _fileForUrl(imageUrl);
    if (await file.exists()) {
      final stat = await file.stat();
      final isFresh =
          DateTime.now().difference(stat.modified) <= _maxCacheAge;
      if (isFresh && stat.size > 0) {
        return file.readAsBytes();
      }
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return await file.exists() ? file.readAsBytes() : null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.isEmpty) {
        return await file.exists() ? file.readAsBytes() : null;
      }

      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (_) {
      return await file.exists() ? file.readAsBytes() : null;
    } finally {
      httpClient.close(force: true);
    }
  }

  String? _normalizeUrl(String? imageUrl) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<File> _fileForUrl(String imageUrl) async {
    final databasesPath = await getDatabasesPath();
    final cacheDirectory = Directory(
      p.join(databasesPath, '..', _cacheFolderName),
    );
    final uri = Uri.tryParse(imageUrl);
    final pathSegments = uri?.pathSegments;
    final extension = _safeExtension(
      pathSegments != null && pathSegments.isNotEmpty ? pathSegments.last : null,
    );
    final fileName = '${_stableHash(imageUrl)}$extension';
    return File(p.join(cacheDirectory.path, fileName));
  }

  String _safeExtension(String? pathSegment) {
    final extension = p.extension(pathSegment ?? '').toLowerCase();
    if (extension.isEmpty || extension.length > 8) {
      return '.img';
    }
    return extension;
  }

  String _stableHash(String input) {
    var hash = 2166136261;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

AdminProductImageCacheService createService() =>
    _IoAdminProductImageCacheService();
