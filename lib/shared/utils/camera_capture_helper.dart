import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'snackbar_helper.dart';

class CameraCaptureHelper {
  CameraCaptureHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<void> pickFromCameraOrGallery(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || source == null) {
      return;
    }

    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (!context.mounted || photo == null) {
        return;
      }

      SnackbarHelper.showSuccess(
        context,
        source == ImageSource.camera
            ? 'Photo added.'
            : 'Image selected.',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      SnackbarHelper.showError(
        context,
        'Unable to open camera. Please try again.',
      );
    }
  }
}
