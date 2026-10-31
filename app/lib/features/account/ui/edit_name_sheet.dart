import 'package:api_client/api_client.dart' show PatchedMeRequest;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/auth/auth_session_guard.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';

const _maxName = 150;

Future<void> showEditNameSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const EditNameSheet(),
    );

/// Bottom sheet with one field: the user's display name.
class EditNameSheet extends ConsumerStatefulWidget {
  const EditNameSheet({super.key});

  @override
  ConsumerState<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<EditNameSheet> {
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    _name = TextEditingController(text: s is SignedIn ? s.user.name : '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = l.editNameBlank);
    if (name.length > _maxName) {
      return setState(() => _error = l.editNameTooLong);
    }
    final current = ref.read(sessionProvider);
    if (current is! SignedIn) return;
    // Captured before the request: a sign-out or switch while it is in
    // flight makes updateName discard the answer.
    final AuthSessionGuard guard = ref.read(authSessionGuardProvider);
    final epoch = guard.epoch;
    final userId = current.user.id;
    final controller = ref.read(sessionProvider.notifier);
    final api = ref.read(apiClientProvider);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      final me = (await api
              .getMeApi()
              .mePartialUpdate(patchedMeRequest: PatchedMeRequest(name: name)))
          .data;
      await controller.updateName(me?.name ?? name,
          epoch: epoch, userId: userId);
      if (navigator.mounted) navigator.pop();
      return;
    } on DioException catch (e) {
      error = _messageOf(mapDioException(e), l);
    } on Object catch (e) {
      error = _messageOf(UnknownError(e), l);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  String _messageOf(AppError e, AppLocalizations l) {
    if (e is ApiError) {
      final field = e.fields['name'];
      if (field != null && field.isNotEmpty) return field.first;
    }
    return userMessage(e, l);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.editNameTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('field_edit_name'),
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: l.editNameLabel,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('edit_name_submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.editNameSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
