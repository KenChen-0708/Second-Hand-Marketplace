import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

enum SnackbarType { success, error, warning, info }

class SnackbarHelper {
  static OverlayEntry? _currentEntry;

  /// Shows a modern snackbar with appropriate icon and styling based on type
  static void showTopMessage(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _removeCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CenteredSnackbarOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Convenience method for showing success messages
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showTopMessage(
      context,
      message,
      type: SnackbarType.success,
      duration: duration,
    );
  }

  /// Convenience method for showing error messages
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    showTopMessage(
      context,
      message,
      type: SnackbarType.error,
      duration: duration,
    );
  }

  /// Convenience method for showing warning messages
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showTopMessage(
      context,
      message,
      type: SnackbarType.warning,
      duration: duration,
    );
  }

  /// Convenience method for showing info messages
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showTopMessage(
      context,
      message,
      type: SnackbarType.info,
      duration: duration,
    );
  }

  static void _removeCurrent() {
    final entry = _currentEntry;
    _currentEntry = null;
    entry?.remove();
  }
}

class _CenteredSnackbarOverlay extends StatefulWidget {
  const _CenteredSnackbarOverlay({
    required this.message,
    required this.onDismissed,
    required this.duration,
    required this.type,
  });

  final String message;
  final SnackbarType type;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_CenteredSnackbarOverlay> createState() =>
      _CenteredSnackbarOverlayState();
}

class _CenteredSnackbarOverlayState extends State<_CenteredSnackbarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isClosing = false;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
    _autoDismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, backgroundColor) = _getIconAndColor(widget.type, colorScheme);

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, -1),
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.onInverseSurface.withValues(
                                    alpha: 0.10,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: colorScheme.onInverseSurface,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.message,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: colorScheme.onInverseSurface,
                                      fontSize: 15,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: _dismiss,
                                borderRadius: BorderRadius.circular(99),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onInverseSurface.withValues(
                                      alpha: 0.10,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: colorScheme.onInverseSurface,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  (IconData, Color) _getIconAndColor(
    SnackbarType type,
    ColorScheme colorScheme,
  ) {
    switch (type) {
      case SnackbarType.success:
        return (
          Icons.check_circle_rounded,
          const Color(0xFF10B981).withValues(alpha: 0.50),
        );
      case SnackbarType.error:
        return (
          Icons.error_outline_rounded,
          const Color(0xFFEF4444).withValues(alpha: 0.50),
        );
      case SnackbarType.warning:
        return (
          Icons.warning_amber_rounded,
          const Color(0xFFF59E0B).withValues(alpha: 0.50),
        );
      case SnackbarType.info:
      default:
        return (
          Icons.info_outline_rounded,
          colorScheme.inverseSurface.withValues(alpha: 0.50),
        );
    }
  }
}
