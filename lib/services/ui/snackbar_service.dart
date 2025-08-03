import 'package:flutter/material.dart';

class SnackbarService {
  static void showSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
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