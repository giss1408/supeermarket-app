import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lists_repository.dart';
import 'quantity_stepper.dart';

const maxItemTextLength = 200;

/// Bottom sheet to add a free-text item with a quantity.
class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key, required this.listLocalId});

  final String listLocalId;

  static Future<void> show(BuildContext context, String listLocalId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => AddItemSheet(listLocalId: listLocalId),
      );

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _controller = TextEditingController();
  int _quantity = 1;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = l.addItemErrorBlank);
      return;
    }
    if (text.length > maxItemTextLength) {
      setState(() => _error = l.addItemErrorTooLong);
      return;
    }
    if (_busy) return;
    _busy = true;
    final navigator = Navigator.of(context);
    await ref
        .read(listsRepositoryProvider)
        .addItem(widget.listLocalId, text: text, quantity: _quantity);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.addItemSubmit, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('add_item_text'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.addItemLabel,
              hintText: l.addItemHint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: QuantityStepper(
              idSuffix: 'new',
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('add_item_submit'),
            onPressed: _submit,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(l.addItemSubmit),
          ),
        ],
      ),
    );
  }
}
