import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/ui/account_screen.dart';
import '../../features/account/ui/register_screen.dart';
import '../../features/account/ui/sign_in_screen.dart';
import '../../features/card/ui/card_screen.dart';
import '../../features/lists/ui/list_detail_screen.dart';
import '../../features/lists/ui/lists_screen.dart';
import '../../features/offers/ui/flyer_archive_screen.dart';
import '../../features/offers/ui/offers_home_screen.dart';
import '../../features/payment/ui/pay_screen.dart';
import '../../features/stores/ui/store_detail_screen.dart';
import '../../features/stores/ui/stores_screen.dart';
import '../ui/app_scaffold.dart';
import '../ui/not_found_page.dart';
import 'routes.dart';
import 'sign_in_gate.dart';

/// One router per container so every test/app instance starts fresh.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// Builds the app router. [offersRoutes] lets tests register extra child
/// routes in the Offers branch; production code leaves it empty.
@visibleForTesting
GoRouter buildAppRouter({List<RouteBase> offersRoutes = const []}) {
  return GoRouter(
    initialLocation: Routes.offers,
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.offers,
              builder: (context, state) => const OffersHomeScreen(),
              routes: [
                GoRoute(
                  path: 'flyers',
                  builder: (context, state) => const FlyerArchiveScreen(),
                ),
                ...offersRoutes,
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.lists,
              builder: (context, state) => const ListsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ListDetailScreen(listId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.stores,
              builder: (context, state) => const StoresScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = int.tryParse(state.pathParameters['id']!);
                    if (id == null) return const NotFoundPage();
                    return StoreDetailScreen(storeId: id);
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.account,
              builder: (context, state) => const AccountScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: Routes.pay,
        builder: (context, state) => const PayScreen(),
      ),
      GoRoute(
        path: Routes.card,
        builder: (context, state) => const CardScreen(),
      ),
      GoRoute(
        path: Routes.signInPath,
        pageBuilder: (context, state) => MaterialPage<bool>(
          fullscreenDialog: true,
          key: state.pageKey,
          child: SignInScreen(
            from: sanitizeFrom(state.uri.queryParameters['from']),
          ),
        ),
      ),
      GoRoute(
        path: Routes.registerPath,
        pageBuilder: (context, state) => MaterialPage<bool>(
          fullscreenDialog: true,
          key: state.pageKey,
          child: RegisterScreen(
            from: sanitizeFrom(state.uri.queryParameters['from']),
          ),
        ),
      ),
    ],
  );
}
