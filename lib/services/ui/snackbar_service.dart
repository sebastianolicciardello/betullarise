import 'dart:async';
import 'package:flutter/material.dart';

class SnackbarService {
  static Timer? _snackbarTimer;

  static void showSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
  }) {
    if (!context.mounted) return;

    // Cancella timer precedente
    _snackbarTimer?.cancel();

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        duration: const Duration(
          seconds: 30,
        ), // Long duration, timer handles dismissal
        action: action,
        backgroundColor: backgroundColor,
      ),
    );

    // Always create a timer for reliable auto-dismissal
    _snackbarTimer = Timer(duration, () {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      }
    });
  }

  static void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showSnackbar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  static void showErrorSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    showSnackbar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  static void showWarningSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    showSnackbar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  static void hideCurrentSnackbar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void clearAllSnackbars(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
