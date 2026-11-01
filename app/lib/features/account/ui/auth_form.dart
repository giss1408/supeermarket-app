import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';

/// Shared sign-in / registration form. Pops `true` on success and `false`
/// when closed.
class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key, required this.register, this.from});

  final bool register;

  /// Already sanitised by the router; only forwarded when switching forms.
  final String? from;

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  Map<String, List<String>> _fieldErrors = const {};
  List<String> _banner = const [];

  static const _knownFields = {'email', 'password', 'name'};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _fieldErrors = const {};
      _banner = const [];
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final controller = ref.read(sessionProvider.notifier);
    try {
      if (widget.register) {
        await controller.register(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
      } else {
        await controller.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      context.pop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(AppError e) {
    final l = AppLocalizations.of(context);
    final fields = <String, List<String>>{};
    final banner = <String>[];
    if (e is ApiError && e.fields.isNotEmpty) {
      e.fields.forEach((key, messages) {
        if (_knownFields.contains(key)) {
          fields[key] = messages;
        } else {
          banner.addAll(messages);
        }
      });
    }
    if (fields.isEmpty && banner.isEmpty) {
      banner.add(
        e is ApiError && e.status == 401 && !widget.register
            ? l.errorWrongCredentials
            : e is ApiError && e.status == 429
                ? l.errorThrottled
                : userMessage(e, l),
      );
    }
    setState(() {
      _fieldErrors = fields;
      _banner = banner;
    });
  }

  String? _serverError(String field) {
    final messages = _fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.join('\n');
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final register = widget.register;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l.errorFieldRequired : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(register ? l.registerTitle : l.signInTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.actionClose,
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_banner.isNotEmpty) ...[
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: Container(
                        key: const Key('auth_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          _banner.join('\n'),
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (register) ...[
                    TextFormField(
                      key: const Key('field_name'),
                      controller: _name,
                      enabled: !_busy,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(
                        labelText: l.fieldName,
                        errorText: _serverError('name'),
                        errorMaxLines: 4,
                      ),
                      onChanged: (_) => _clearError('name'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    key: const Key('field_email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    autofillHints: [
                      register ? AutofillHints.email : AutofillHints.username,
                    ],
                    decoration: InputDecoration(
                      labelText: l.fieldEmail,
                      errorText: _serverError('email'),
                      errorMaxLines: 4,
                    ),
                    validator: required,
                    onChanged: (_) => _clearError('email'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('field_password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: l.fieldPassword,
                      errorText: _serverError('password'),
                      errorMaxLines: 6,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? l.showPassword : l.hidePassword,
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? l.errorFieldRequired : null,
                    onChanged: (_) => _clearError('password'),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('auth_submit'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l.busyLabel,
                            ),
                          )
                        : Text(register ? l.actionRegister : l.actionSignIn),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('auth_switch'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy
                        ? null
                        : () => context.pushReplacement(
                              register
                                  ? Routes.signIn(from: widget.from)
                                  : Routes.register(from: widget.from),
                            ),
                    child: Text(
                      register ? l.switchToSignIn : l.switchToRegister,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
