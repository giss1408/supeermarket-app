import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/database_provider.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/util/clock.dart';
import 'package:supermarket_app/features/offers/data/offers_repository.dart';
import 'package:supermarket_app/features/offers/state/offers_providers.dart';

import '../core/db/test_db.dart';
import 'fake_http.dart';

Object fixture(String name) =>
    json.decode(File('test/fixtures/$name.json').readAsStringSync()) as Object;

/// Real repository on an in-memory DB and a scripted HTTP adapter.
class Harness {
  Harness({DateTime? start}) : now = start ?? DateTime.utc(2026, 10, 29, 8) {
    db = createTestDb();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = http;
    final client = ApiClient(dio: dio, interceptors: const []);
    repo = OffersRepository(
      flyersApi: client.getFlyersApi(),
      categoriesApi: client.getCategoriesApi(),
      db: db,
      clock: () => now,
    );
    http.reply('GET', '/flyers/current', 200, fixture('flyers_current'));
    http.reply('GET', '/categories', 200, fixture('categories_list'));
    http.reply('GET', '/flyers', 200, fixture('flyers_list'));
  }

  late final AppDatabase db;
  late final OffersRepository repo;
  final http = FakeAdapter();
  DateTime now;

  int get flyerCalls => http.callsTo('/flyers/current').length;
  Future<List<OfferRow>> offerRows() => db.select(db.offers).get();

  List<Override> get overrides => [
        appDatabaseProvider.overrideWithValue(db),
        offersRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ];

  /// [home] at `/`, plus a marker page at the archive route unless the home
  /// widget is the archive itself.
  Widget app(Widget home, {ThemeData? theme, double textScale = 1}) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(
          path: Routes.flyerArchive,
          builder: (_, __) => const Scaffold(body: Text('ARCHIVE-PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme ?? lightTheme(Brand.neutral),
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

/// `testWidgets` that unmounts the tree at the end so drift's stream-close
/// timers do not count as pending timers.
void offersTest(
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
