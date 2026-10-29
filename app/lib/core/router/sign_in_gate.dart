import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_controller.dart';
import 'routes.dart';

/// Holds the in-flight sign-in so overlapping calls share one dialog.
/// One instance per ProviderContainer (never global).
class SignInGate {
  Future<bool>? pending;
}

final signInGateProvider = Provider<SignInGate>((ref) => SignInGate());

/// Returns true when the user is signed in, opening the sign-in dialog first
/// when needed. Returns false if the dialog is closed without signing in.
/// After success the user is back on the originating screen (the dialog pops).
///
/// Safe if the calling widget is disposed while the dialog is open: [ref] is
/// not used (only the container captured beforehand). A second call while the
/// dialog is open returns the same pending future.
Future<bool> requireSignIn(BuildContext context, WidgetRef ref) {
  final container = ProviderScope.containerOf(context);
  if (container.read(sessionProvider) is SignedIn) return Future.value(true);
  final gate = container.read(signInGateProvider);
  final existing = gate.pending;
  if (existing != null) return existing;

  final router = GoRouter.of(context);
  final from = sanitizeFrom(currentLocation(router));
  final future = _open(container, gate, router, from);
  gate.pending = future;
  return future;
}

Future<bool> _open(
  ProviderContainer container,
  SignInGate gate,
  GoRouter router,
  String? from,
) async {
  // Switching sign-in <-> register uses pushReplacement, which drops the
  // completer of the original push: its future would never complete. The
  // gate therefore also finishes when the auth routes are gone from the
  // stack, and the session (not a pop result) says whether sign-in worked.
  final done = Completer<void>();
  var seenAuthRoute = false;
  void check() {
    final path = Uri.tryParse(currentLocation(router))?.path;
    if (path == Routes.signInPath || path == Routes.registerPath) {
      seenAuthRoute = true;
    } else if (seenAuthRoute && !done.isCompleted) {
      done.complete();
    }
  }

  router.routerDelegate.addListener(check);
  try {
    unawaited(router.push<bool>(Routes.signIn(from: from)).then<void>((_) {
      if (!done.isCompleted) done.complete();
    }));
    await done.future;
    return container.read(sessionProvider) is SignedIn;
  } finally {
    router.routerDelegate.removeListener(check);
    gate.pending = null;
  }
}

const _allowedRoots = {'offers', 'lists', 'stores', 'account', 'pay'};
final _encodedBad =
    RegExp(r'%(0[0-9a-f]|1[0-9a-f]|7f|5c)', caseSensitive: false);

/// Accepts only known app-internal locations; anything else becomes null.
String? sanitizeFrom(String? from) {
  if (from == null || from.isEmpty || from.length > 2048) return null;
  if (!from.startsWith('/') || from.startsWith('//')) return null;
  for (final c in from.codeUnits) {
    if (c <= 0x20 || c == 0x7F || c == 0x5C) return null;
  }
  if (_encodedBad.hasMatch(from)) return null;
  final lower = from.toLowerCase();
  if (lower.startsWith('/%2f') || lower.startsWith('/%5c')) return null;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final end = from.indexOf(RegExp(r'[?#]'));
  final rawPath = end < 0 ? from : from.substring(0, end);
  final segments = rawPath.split('/');
  if (segments.contains('.') || segments.contains('..')) return null;
  if (!_allowedRoots.contains(segments.length > 1 ? segments[1] : '')) {
    return null;
  }
  return from;
}

/// Location of the topmost page, including imperatively pushed ones (the
/// router's own `uri` ignores those).
String currentLocation(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.matches.isEmpty ? null : config.matches.last;
  if (last is ImperativeRouteMatch) return last.matches.uri.toString();
  return config.uri.toString();
}
