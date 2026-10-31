import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/db/app_database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/router/routes.dart';
import '../../../core/router/sign_in_gate.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../data/lists_repository.dart';
import '../state/lists_providers.dart';
import 'list_name_dialog.dart';
import 'sync_status_chip.dart';

const undoDuration = Duration(seconds: 5);

/// Lists tab: guests get a sign-in prompt, signed-in users their lists.
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  // Dismissed rows leave the tree in the same frame; the DB stream follows.
  final _hidden = <String>{};

  Future<void> _create() async {
    final name = await promptListName(context);
    if (name == null || !mounted) return;
    await ref.read(listsRepositoryProvider).createList(name);
  }

  Future<void> _delete(ShoppingListRow list) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(listsRepositoryProvider);
    setState(() => _hidden.add(list.localId));
    final items = (await repo.watchList(list.localId).first)?.items ?? [];
    await repo.deleteList(list.localId);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(l.listDeleted),
      duration: undoDuration,
      action: SnackBarAction(
        label: l.listUndo,
        // There is no server-side undo: the list is created again.
        onPressed: () async {
          final id = await repo.createList(list.name);
          for (final item in items) {
            final newId = await repo.addItem(
              id,
              productId: item.productId,
              productName: item.productName,
              productUnit: item.productUnit,
              productImageUrl: item.productImageUrl,
              text: item.itemText,
              quantity: item.quantity,
            );
            if (item.checked) await repo.updateItem(newId, checked: true);
          }
        },
      ),
    ));
  }

  Future<void> _refresh() => ref.read(syncCoordinatorProvider).run(force: true);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider) is SignedIn;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabLists)),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              key: const Key('new_list'),
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l.listsNewList),
            )
          : null,
      body: signedIn ? _signedIn(l) : _guest(l),
    );
  }

  Widget _guest(AppLocalizations l) => EmptyState(
        icon: Icons.list_alt,
        title: l.listsGuestPrompt,
        actionLabel: l.actionSignIn,
        onAction: () => requireSignIn(context, ref),
      );

  Widget _signedIn(AppLocalizations l) {
    final lists = ref.watch(listsProvider);
    return lists.when(
      // Local data: no spinner (it would only flash for a few ms).
      loading: () => const SizedBox.shrink(),
      error: (e, _) => ErrorView(
        error: UnknownError(e),
        onRetry: () => ref.invalidate(listsProvider),
      ),
      data: (all) {
        final visible = all.where((x) => !_hidden.contains(x.localId)).toList();
        return Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: SyncStatusChip(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: visible.isEmpty
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.list_alt,
                              title: l.listsEmptyTitle,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => _ListRow(
                          list: visible[i],
                          onDelete: () => _delete(visible[i]),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({required this.list, required this.onDelete});

  final ShoppingListRow list;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final detail = ref.watch(listDetailProvider(list.localId)).valueOrNull;
    final items = detail?.items ?? const [];
    final checked = items.where((i) => i.checked).length;
    final summary = items.isEmpty
        ? l.listItemCount(0)
        : '${l.listItemCount(items.length)} · '
            '${l.listCheckedOf(checked, items.length)}';
    return Dismissible(
      key: Key('list_${list.localId}'),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(list.name),
        subtitle: Text(summary),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.listDetail(list.localId)),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}
