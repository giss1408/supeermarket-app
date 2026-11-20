import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/brand_logo.dart';

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

/// With the auth service the form has three steps: credentials, then (new account, or an account not yet activated) the WhatsApp code, or
/// (signed in with a temporary password) the choice of a new password.
enum _Step { credentials, activation, newPassword }

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordConfirm = TextEditingController();

  _Step _step = _Step.credentials;
  String? _info;

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
    _code.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
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
    final authMode = ref.read(authModeProvider);
    try {
      if (authMode) {
        final done = await _submitAtAuth(controller);
        if (!done) return;
      } else if (widget.register) {
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
    } on PasswordChangeRequired {
      if (!mounted) return;
      setState(() => _step = _Step.newPassword);
    } on AppError catch (e) {
      if (!mounted) return;
      if (authMode &&
          e is ApiError &&
          e.code == 'not_activated' &&
          _step == _Step.credentials) {
        // The account exists but the team's code was never typed: go straight to the code.
        setState(() {
          _step = _Step.activation;
          _info = null;
        });
        return;
      }
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// One submit at the auth service; true when the session is open (the form can close), false when it moves to another step.
  Future<bool> _submitAtAuth(SessionController controller) async {
    switch (_step) {
      case _Step.credentials:
        if (widget.register) {
          await controller.registerPhone(
            phone: _email.text,
            password: _password.text,
            name: _name.text,
          );
          if (mounted) setState(() => _step = _Step.activation);
          return false;
        }
        await controller.signIn(_email.text, _password.text);
        return true;
      case _Step.activation:
        await controller.activate(
          phone: _email.text,
          code: _code.text,
          password: _password.text,
        );
        return true;
      case _Step.newPassword:
        await controller.completePasswordChange(_newPassword.text);
        return true;
    }
  }

  Future<void> _forgotPassword() async {
    if (_busy) return;
    final phone = _email.text.trim();
    if (phone.isEmpty) {
      setState(() => _fieldErrors = {
            'email': [AppLocalizations.of(context).errorFieldRequired]
          });
      return;
    }
    setState(() {
      _busy = true;
      _banner = const [];
    });
    try {
      await ref.read(sessionProvider.notifier).requestPasswordReset(phone);
      if (mounted) {
        setState(() => _info = AppLocalizations.of(context).forgotPasswordSent);
      }
    } on AppError catch (e) {
      if (mounted) _showError(e);
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
        e is ApiError &&
                (e.status == 401 || e.code == 'invalid_credentials') &&
                !widget.register
            ? (ref.read(authModeProvider)
                ? l.errorWrongCredentialsPhone
                : l.errorWrongCredentials)
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
    final authMode = ref.watch(authModeProvider);
    final credentials = _step == _Step.credentials;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l.errorFieldRequired : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (_step) {
            _Step.activation => l.activationTitle,
            _Step.newPassword => l.newPasswordTitle,
            _Step.credentials => register ? l.registerTitle : l.signInTitle,
          },
        ),
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
                  const Center(child: BrandLogo()),
                  const SizedBox(height: Space.lg),
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
                  if (_info != null) ...[
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: Container(
                        key: const Key('auth_info'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          _info!,
                          style: TextStyle(color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_step == _Step.activation) ...[
                    Text(l.activationInfo, key: const Key('activation_info')),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('field_code'),
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: l.fieldActivationCode,
                        errorMaxLines: 4,
                      ),
                      validator: (v) => (v == null || v.trim().length != 6)
                          ? l.errorFieldRequired
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_step == _Step.newPassword) ...[
                    Text(l.newPasswordInfo,
                        key: const Key('new_password_info')),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('field_new_password'),
                      controller: _newPassword,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                          labelText: l.fieldNewPassword, errorMaxLines: 6),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l.errorFieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('field_new_password_confirm'),
                      controller: _newPasswordConfirm,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration:
                          InputDecoration(labelText: l.fieldNewPasswordConfirm),
                      validator: (v) => v != _newPassword.text
                          ? l.errorPasswordsDiffer
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (credentials && register) ...[
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
                  if (credentials) ...[
                    TextFormField(
                      key: Key(authMode ? 'field_phone' : 'field_email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: authMode
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: authMode
                          ? [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ]'))
                            ]
                          : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      autofillHints: authMode
                          ? const [AutofillHints.telephoneNumber]
                          : [
                              register
                                  ? AutofillHints.email
                                  : AutofillHints.username
                            ],
                      decoration: InputDecoration(
                        labelText: authMode ? l.fieldPhone : l.fieldEmail,
                        hintText: authMode ? l.fieldPhoneHint : null,
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
                      validator: (v) => (v == null || v.isEmpty)
                          ? l.errorFieldRequired
                          : null,
                      onChanged: (_) => _clearError('password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (authMode && !register)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('auth_forgot'),
                          onPressed: _busy ? null : _forgotPassword,
                          child: Text(l.actionForgotPassword),
                        ),
                      ),
                  ],
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
                        : Text(
                            switch (_step) {
                              _Step.activation => l.actionActivate,
                              _Step.newPassword => l.actionSavePassword,
                              _Step.credentials =>
                                register ? l.actionRegister : l.actionSignIn,
                            },
                          ),
                  ),
                  if (credentials) ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
