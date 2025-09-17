import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';

class DialogService {
  // Dialog di caricamento
  DialogRoute showLoadingDialog(BuildContext context, String message) {
    return DialogRoute(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              SizedBox(width: 20.w),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Dialog di conferma generico
  Future<bool?> showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Continue',
    String cancelText = 'Cancel',
    Color? confirmColor,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            Navigator.of(context).pop(false);
          },
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: isDangerous 
                      ? Colors.red 
                      : confirmColor ?? Theme.of(context).colorScheme.primary,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog di risultato/informazione
  Future<void> showResultDialog(
    BuildContext context,
    String title,
    String message, {
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text(buttonText),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Dialog per input di testo/numeri
  Future<String?> showInputDialog(
    BuildContext context,
    String title, {
    String? message,
    String initialValue = '',
    String labelText = '',
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final focusNode = FocusNode();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        // Auto-focus and open keyboard on Android after dialog is shown
        if (Platform.isAndroid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            focusNode.requestFocus();
          });
        }

        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) ...[
                  Text(message),
                  SizedBox(height: 16.h),
                ],
                TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: labelText,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: keyboardType,
                  validator: validator,
                  autofocus: Platform.isAndroid,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                focusNode.dispose();
                Navigator.of(context).pop();
              },
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  focusNode.dispose();
                  Navigator.of(context).pop(controller.text);
                }
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  // Dialog per selezione da una lista
  Future<T?> showSelectionDialog<T>(
    BuildContext context,
    String title,
    List<T> items, {
    String? message,
    String Function(T)? itemLabelBuilder,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null) ...[
                  Text(message),
                  SizedBox(height: 16.h),
                ],
                ...items.map(
                  (item) => ListTile(
                    title: Text(itemLabelBuilder?.call(item) ?? item.toString()),
                    onTap: () => Navigator.of(context).pop(item),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
          ],
        );
      },
    );
  }
}
