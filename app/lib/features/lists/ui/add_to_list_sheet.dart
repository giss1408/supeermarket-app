import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/ui/error_view.dart';
import '../data/lists_repository.dart';
import '../state/lists_providers.dart';
import 'list_name_dialog.dart';

/// Pick (or create) a list, then add the offer's product to it.
/// Callers make sure the user is signed in first.
class AddToListSheet extends ConsumerWidget {
  const AddToListSheet({super.key, required this.item});

  final OfferWithProduct item;

  static Future<void> show(BuildContext context, OfferWithProduct item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => AddToListSheet(item: item),
      );

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String listId,
    String listName,
  ) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final product = item.product;
    await ref.read(listsRepositoryProvider).addItem(
          listId,
          productId: product.id,
          productName: product.name,
          productUnit: product.unit,
          productImageUrl: product.imageUrl,
          quantity: 1,
        );
    messenger.showSnackBar(SnackBar(content: Text(l.addToListAdded(listName))));
    navigator.pop();
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final name = await promptListName(context);
    if (name == null || !context.mounted) return;
    final id = await ref.read(listsRepositoryProvider).createList(name);
    if (!context.mounted) return;
    await _add(context, ref, id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lists = ref.watch(listsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.addToListTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            key: const Key('add_to_new_list'),
            leading: const Icon(Icons.add),
            title: Text(l.listsNewList),
            onTap: () => _createAndAdd(context, ref),
          ),
          if (lists.hasError)
            ErrorView(
              error: UnknownError(lists.error!),
              onRetry: () => ref.invalidate(listsProvider),
            )
          else
            for (final list in lists.valueOrNull ?? const <ShoppingListRow>[])
              ListTile(
                key: Key('add_to_${list.localId}'),
                leading: const Icon(Icons.list_alt),
                title: Text(list.name),
                onTap: () => _add(context, ref, list.localId, list.name),
              ),
          if (lists.valueOrNull?.isEmpty ?? false)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.addToListEmpty),
            ),
        ],
      ),
    );
  }
}
