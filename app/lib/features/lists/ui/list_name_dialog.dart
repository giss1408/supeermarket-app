import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/lists_repository.dart';

/// Asks for a list name (1-100 chars). Returns the trimmed name or null.
Future<String?> promptListName(
  BuildContext context, {
  String? initial,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ListNameDialog(initial: initial),
    );

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({this.initial});

  final String? initial;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final renaming = widget.initial != null;
    return AlertDialog(
      title: Text(renaming ? l.listNameRenameTitle : l.listNameCreateTitle),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l.listNameLabel),
          validator: (v) {
            final n = (v ?? '').trim();
            if (n.isEmpty) return l.listNameErrorBlank;
            if (n.length > maxListNameLength) return l.listNameErrorTooLong;
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.listCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(renaming ? l.listSave : l.listCreate),
        ),
      ],
    );
  }
}
