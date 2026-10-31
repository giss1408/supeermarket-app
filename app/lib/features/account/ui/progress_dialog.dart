import 'package:flutter/material.dart';

/// Blocking progress dialog (not dismissible, no back). Close it with
/// `navigator.pop()` on the navigator returned by [showBlockingProgress].
NavigatorState showBlockingProgress(BuildContext context, String label) {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  return navigator;
}
