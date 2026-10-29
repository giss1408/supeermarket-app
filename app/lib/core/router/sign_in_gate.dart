import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_controller.dart';
import 'routes.dart';

/// Returns true when the user is signed in, opening the sign-in dialog first
/// when needed. Returns false if the dialog is closed without signing in.
/// After success the user is back on the originating screen (the dialog pops).
Future<bool> requireSignIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(sessionProvider) is SignedIn) return true;
  final router = GoRouter.of(context);
  final from = currentLocation(router);
  final result = await context.push<bool>(Routes.signIn(from: from));
  return result == true && ref.read(sessionProvider) is SignedIn;
}

/// Accepts only app-internal locations ("/x", not "//x", no scheme).
String? sanitizeFrom(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//')) return null;
  if (from.startsWith('/\\') || from.contains('\n') || from.contains('\r')) {
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
