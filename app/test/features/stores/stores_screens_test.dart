import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/database_provider.dart';
import 'package:supermarket_app/core/location/location_service.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/ui/offline_banner.dart';
import 'package:supermarket_app/core/util/clock.dart';
import 'package:supermarket_app/core/util/url_opener.dart';
import 'package:supermarket_app/features/stores/data/stores_repository.dart';
import 'package:supermarket_app/features/stores/state/stores_providers.dart';
import 'package:supermarket_app/features/stores/ui/store_detail_screen.dart';
import 'package:supermarket_app/features/stores/ui/stores_screen.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_http.dart';
import '../../support/offers_harness.dart' show fixture;

class FakeLocation implements LocationService {
  FakeLocation(this.initial, {this.afterPrompt});
  LocationResult initial;
  LocationResult? afterPrompt;
  final prompts = <bool>[];
  var settingsOpened = 0;

  @override
  Future<LocationResult> current({bool prompt = false}) async {
    prompts.add(prompt);
    if (prompt && afterPrompt != null) return initial = afterPrompt!;
    return initial;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class FakeOpener implements UrlOpener {
  final opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

class H {
  H({LocationResult location = const Denied()}) : loc = FakeLocation(location) {
    db = createTestDb();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = http;
    repo = StoresRepository(
      storesApi: ApiClient(dio: dio, interceptors: const []).getStoresApi(),
      db: db,
      clock: () => now,
    );
    http.reply('GET', '/stores', 200, fixture('stores_list'));
    for (final id in [1, 2, 3, 4, 5]) {
      http.on('GET', '/stores/$id', (_, __) {
        final d = Map<String, dynamic>.from(fixture('store_detail') as Map);
        d['id'] = id;
        return FakeResponse(200, d);
      });
    }
  }

  late final AppDatabase db;
  late final StoresRepository repo;
  final http = FakeAdapter();
  final FakeLocation loc;
  final opener = FakeOpener();
  // Thursday 08:00.
  DateTime now = DateTime(2026, 10, 29, 8);

  Widget app({String initial = '/', double textScale = 1}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const StoresScreen()),
        GoRoute(
          path: '/stores/:id',
          builder: (_, s) => StoreDetailScreen(
            storeId: int.parse(s.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: Routes.pay,
          builder: (_, __) => const Scaffold(body: Text('PAY-PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storesRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
        locationServiceProvider.overrideWithValue(loc),
        urlOpenerProvider.overrideWithValue(opener),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: lightTheme(Brand.neutral),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void storesTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// Vertical order of store names on screen.
List<String> order(WidgetTester tester, List<String> names) {
  final tops = {for (final n in names) n: tester.getTopLeft(find.text(n)).dy};
  return (tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!)));
}

const plateau = 'Supermarché Plateau';
const bouake = 'Supermarché Bouaké Centre';
const cocody = 'Supermarché Cocody Angré';

void main() {
  storesTest('sorted by distance when granted, alphabetical when denied',
      (tester) async {
    final g = H(location: const Granted(5.322, -4.021));
    await tester.runAsync(() => g.repo.refresh());
    await tester.pumpWidget(g.app());
    await settle(tester);
    var names = order(tester, [plateau, bouake, cocody]);
    expect(names, [plateau, cocody, bouake]);
    expect(find.text('0 m'), findsOneWidget);
    expect(find.text('Autoriser'), findsNothing);
    expect(g.loc.prompts, [false]);
  });

  storesTest('denied: alphabetical, location card, Autoriser prompts',
      (tester) async {
    final h = H();
    h.loc.afterPrompt = const Granted(5.322, -4.021);
    await tester.runAsync(() => h.repo.refresh());
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(order(tester, [plateau, bouake, cocody]), [bouake, cocody, plateau]);
    expect(find.text('Activez la localisation pour trier par distance'),
        findsOneWidget);

    await tester.tap(find.text('Autoriser'));
    await settle(tester);
    expect(h.loc.prompts, [false, true]);
    expect(find.text('Autoriser'), findsNothing);
    expect(order(tester, [plateau, bouake, cocody]), [plateau, cocody, bouake]);
  });

  storesTest('permanently denied offers the settings button', (tester) async {
    final h = H(location: const Denied(permanent: true));
    await tester.runAsync(() => h.repo.refresh());
    await tester.pumpWidget(h.app());
    await settle(tester);
    await tester.tap(find.text('Ouvrir les réglages'));
    await settle(tester);
    expect(h.loc.settingsOpened, 1);
  });

  storesTest('search is accent-insensitive; badge follows the clock',
      (tester) async {
    final h = H();
    await tester.runAsync(() => h.repo.refresh());
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(find.text('Ouvert'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'bouake');
    await settle(tester);
    expect(find.text(bouake), findsOneWidget);
    expect(find.text(plateau), findsNothing);

    h.now = DateTime(2026, 10, 29, 23);
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(find.text('Fermé'), findsWidgets);
    expect(find.text('Ouvert'), findsNothing);
  });

  storesTest('offline with cached stores shows the banner', (tester) async {
    final h = H();
    await tester.runAsync(() => h.repo.refresh());
    h.now = h.now.add(const Duration(days: 2));
    h.http.on('GET', '/stores', offline());
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text(plateau), findsOneWidget);
  });

  storesTest('tile opens the detail: today highlighted, tel, maps, pay',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600); // whole detail visible
    final h = H();
    await tester.runAsync(() => h.repo.refresh());
    await tester.pumpWidget(h.app());
    await settle(tester);

    await tester.tap(find.text(cocody));
    await settle(tester);
    expect(find.text('Ouvert maintenant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hours-today')),
        matching: find.text('Jeudi'),
      ),
      findsOneWidget,
    );
    expect(find.text('Dimanche', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('+2252722000101'));
    await settle(tester);
    expect(h.opener.opened.last.toString(), 'tel:+2252722000101');

    await tester.tap(find.text('Itinéraire'));
    await settle(tester);
    expect(
      h.opener.opened.last.toString(),
      'https://www.google.com/maps/search/?api=1&query=5.4015,-3.987',
    );

    h.opener.result = false;
    await tester.tap(find.text('Itinéraire'));
    await settle(tester);
    expect(find.text("Impossible d'ouvrir l'application de cartes"),
        findsOneWidget);

    await tester.tap(find.text('Payer par mobile money'));
    await tester.pumpAndSettle();
    expect(find.text('PAY-PAGE'), findsOneWidget);
  });

  storesTest('unknown store with a failed refresh shows an empty state',
      (tester) async {
    final h = H();
    h.http.on('GET', '/stores/99', offline());
    await tester.pumpWidget(h.app(initial: '/stores/99'));
    await settle(tester);
    expect(find.text('Magasin introuvable'), findsOneWidget);
  });

  storesTest('no overflow at 320dp and text scale 2.0', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    final h = H();
    await tester.runAsync(() => h.repo.refresh());
    await tester.pumpWidget(h.app(textScale: 2));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(h.app(initial: '/stores/1', textScale: 2));
    await settle(tester);
    expect(find.text('Itinéraire', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  storesTest('a store without hour rows shows no open/closed badge',
      (tester) async {
    final h = H();
    await tester.runAsync(() async {
      await h.repo.refresh();
      final plateau = await (h.db.select(h.db.stores)
            ..where((t) => t.id.equals(4)))
          .getSingle();
      await h.db.storesDao.upsertStoreWithHours(plateau, const []);
    });
    await tester.pumpWidget(h.app());
    await settle(tester);
    // Four stores with hours (open at 08:00), Plateau (4) has none.
    expect(find.text('Ouvert', skipOffstage: false), findsNWidgets(4));
    expect(find.text('Fermé', skipOffstage: false), findsNothing);
  });
}
