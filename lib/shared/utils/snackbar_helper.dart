import 'package:flutter/material.dart';

class SnackbarHelper {
  static void showTopMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(message),
          backgroundColor:
              backgroundColor ?? Theme.of(context).colorScheme.inverseSurface,
          contentTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
          leading: Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text(
                'Dismiss',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
      );

    Future.delayed(const Duration(seconds: 3), () {
      messenger.hideCurrentMaterialBanner();
    });
  }
}
