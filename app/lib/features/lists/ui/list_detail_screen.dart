import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../data/lists_repository.dart';
import '../state/lists_providers.dart';
import 'add_item_sheet.dart';
import 'list_name_dialog.dart';
import 'lists_screen.dart' show undoDuration;
import 'quantity_stepper.dart';
import 'sync_status_chip.dart';

/// One list: tick items off, change quantities, add and delete (all local).
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  // Dismissed rows leave the tree in the same frame; the DB stream follows.
  final _hidden = <String>{};

  ListsRepository get _repo => ref.read(listsRepositoryProvider);

  Future<void> _rename(String current) async {
    final name = await promptListName(context, initial: current);
    if (name == null || !mounted || name == current) return;
    await _repo.renameList(widget.listId, name);
  }

  Future<void> _delete(ListItemRow item) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = _repo;
    setState(() => _hidden.add(item.localId));
    await repo.deleteItem(item.localId);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(l.listItemDeleted),
      duration: undoDuration,
      action: SnackBarAction(
        label: l.listUndo,
        // There is no server-side undo: the item is added again.
        onPressed: () async {
          final id = await repo.addItem(
            item.listLocalId,
            productId: item.productId,
            productName: item.productName,
            productUnit: item.productUnit,
            productImageUrl: item.productImageUrl,
            text: item.itemText,
            quantity: item.quantity,
          );
          if (item.checked) await repo.updateItem(id, checked: true);
        },
      ),
    ));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.lists);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final detail = ref.watch(listDetailProvider(widget.listId));
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.tabLists)),
        body: const SizedBox.shrink(), // local data: loads in a few ms
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l.tabLists)),
        body: ErrorView(
          error: UnknownError(e),
          onRetry: () => ref.invalidate(listDetailProvider(widget.listId)),
        ),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.tabLists)),
            body: EmptyState(
              icon: Icons.list_alt,
              title: l.listNotFoundTitle,
              actionLabel: l.listNotFoundAction,
              onAction: _back,
            ),
          );
        }
        return _body(l, data);
      },
    );
  }

  Widget _body(AppLocalizations l, ListWithItems data) {
    final items = data.items.where((i) => !_hidden.contains(i.localId));
    final visible = items.toList();
    final checked = visible.where((i) => i.checked).length;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(data.list.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('rename_list'),
            tooltip: l.listRenameTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(data.list.name),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('add_item'),
            onPressed: () => AddItemSheet.show(context, widget.listId),
            icon: const Icon(Icons.add),
            label: Text(l.listAddItem),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
      body: ListView(
        children: [
          const SyncStatusChip(),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.listEmptyItems, textAlign: TextAlign.center),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l.listCheckedOf(checked, visible.length),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final item in visible)
              _ItemRow(
                key: Key('item_${item.localId}'),
                item: item,
                onDelete: () => _delete(item),
              ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({super.key, required this.item, required this.onDelete});

  final ListItemRow item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(listsRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final name = (item.productName?.isNotEmpty ?? false)
        ? item.productName!
        : item.itemText;
    final unit = item.productUnit;
    return Dismissible(
      key: ValueKey('dismiss_${item.localId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: Key('check_${item.localId}'),
            controlAffinity: ListTileControlAffinity.leading,
            value: item.checked,
            onChanged: (v) =>
                repo.updateItem(item.localId, checked: v ?? false),
            title: Text(
              name,
              style: item.checked
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: scheme.onSurfaceVariant,
                    )
                  : null,
            ),
            subtitle: (unit != null && unit.isNotEmpty) ? Text(unit) : null,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: QuantityStepper(
                idSuffix: item.localId,
                value: item.quantity,
                onChanged: (q) => repo.updateItem(item.localId, quantity: q),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
