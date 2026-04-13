import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'snackbar_helper.dart';

class CameraCaptureHelper {
  CameraCaptureHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<void> openCamera(BuildContext context) async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (!context.mounted || photo == null) {
        return;
      }

      SnackbarHelper.showSuccess(context, 'Photo captured successfully.');
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      SnackbarHelper.showError(
        context,
        'Unable to open the camera right now. Please try again.',
      );
    }
  }
}
