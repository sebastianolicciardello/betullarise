import 'package:flutter/material.dart';

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
              const SizedBox(width: 20),
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
      builder: (BuildContext context) {
        return AlertDialog(
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

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) ...[
                  Text(message),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: labelText,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: keyboardType,
                  validator: validator,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
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
                  const SizedBox(height: 16),
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
