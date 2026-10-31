import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/database_provider.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/ui/empty_state.dart';
import 'package:supermarket_app/features/lists/data/lists_repository.dart';
import 'package:supermarket_app/features/lists/ui/add_to_list_sheet.dart';
import 'package:supermarket_app/features/lists/ui/list_detail_screen.dart';
import 'package:supermarket_app/features/lists/ui/lists_screen.dart';
import 'package:supermarket_app/features/offers/ui/offer_detail_sheet.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_session_controller.dart';

/// Real repository on an in-memory DB that records the calls the UI makes.
class LoggingRepo extends ListsRepository {
  LoggingRepo(AppDatabase db)
      : super(db: db, clock: () => DateTime.utc(2026, 10, 29, 8));

  final log = <String>[];

  @override
  Future<String> createList(String name) {
    log.add('createList:$name');
    return super.createList(name);
  }

  @override
  Future<String> addItem(
    String listLocalId, {
    int? productId,
    String? productName,
    String? productUnit,
    String? productImageUrl,
    String text = '',
    int quantity = 1,
  }) {
    log.add('addItem:${productId ?? text}:${productName ?? ''}:$quantity');
    return super.addItem(
      listLocalId,
      productId: productId,
      productName: productName,
      productUnit: productUnit,
      productImageUrl: productImageUrl,
      text: text,
      quantity: quantity,
    );
  }

  @override
  Future<void> updateItem(
    String itemLocalId, {
    int? quantity,
    bool? checked,
    String? text,
  }) {
    log.add('updateItem:quantity=$quantity,checked=$checked');
    return super.updateItem(
      itemLocalId,
      quantity: quantity,
      checked: checked,
      text: text,
    );
  }
}

class _Session extends FakeSessionController {
  _Session(this.initial);
  final Session initial;
  @override
  Session build() => initial;
}

class Env {
  Env(this.db, this.repo);
  final AppDatabase db;
  final LoggingRepo repo;
}

Env newEnv() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = createTestDb();
  return Env(db, LoggingRepo(db));
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<T> real<T>(WidgetTester t, Future<T> Function() f) async =>
    (await t.runAsync(f)) as T;

Future<void> pumpApp(
  WidgetTester t,
  Env env,
  Widget home, {
  bool signedIn = true,
  double scale = 1,
  Size? size,
}) async {
  if (size != null) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => home),
    GoRoute(
      path: '/lists/:id',
      builder: (_, s) => ListDetailScreen(listId: s.pathParameters['id']!),
    ),
  ]);
  addTearDown(router.dispose);
  final session =
      signedIn ? const SignedIn(FakeSessionController.user) : const Guest();
  await t.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(env.db),
      listsRepositoryProvider.overrideWithValue(env.repo),
      sessionProvider.overrideWith(() => _Session(session)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: lightTheme(Brand.neutral),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  ));
  await settle(t);
  env.repo.log.clear();
}

void listsTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

Finder byKey(String k) => find.byKey(Key(k));

void main() {
  listsTest('guest sees the sign-in prompt and no list names', (t) async {
    final env = newEnv();
    await real(t, () => env.repo.createList('Secrète'));
    await pumpApp(t, env, const ListsScreen(), signedIn: false);
    expect(find.text('Connectez-vous pour créer vos listes'), findsOneWidget);
    expect(find.text('Secrète'), findsNothing);
  });

  listsTest('create a list offline: appears at once, chip says 1 en attente',
      (t) async {
    final env = newEnv();
    await pumpApp(t, env, const ListsScreen());
    expect(
        find.text('Aucune liste pour le moment. Créez votre première liste.'),
        findsOneWidget);
    await t.tap(byKey('new_list'));
    await settle(t);
    await t.tap(find.text('Créer'));
    await settle(t);
    expect(find.text('Saisissez un nom pour la liste.'), findsOneWidget);
    await t.enterText(find.byType(TextFormField), 'Fêtes');
    await t.tap(find.text('Créer'));
    await settle(t);
    expect(find.text('Fêtes'), findsOneWidget);
    expect(find.text('1 en attente'), findsOneWidget);
  });

  listsTest('tick-off and quantity stepper clamp at 1 and 999', (t) async {
    final env = newEnv();
    final listId = await real(t, () => env.repo.createList('Courses'));
    final low = await real(t, () => env.repo.addItem(listId, text: 'Lait'));
    final high = await real(
        t, () => env.repo.addItem(listId, text: 'Riz', quantity: 999));
    await pumpApp(t, env, ListDetailScreen(listId: listId));

    await t.tap(byKey('check_$low'));
    await settle(t);
    expect(env.repo.log, contains('updateItem:quantity=null,checked=true'));

    final dec = t.widget<IconButton>(byKey('qty_dec_$low'));
    expect(dec.onPressed, isNull);
    expect(t.getSize(byKey('qty_dec_$low')), const Size(48, 48));
    await t.tap(byKey('qty_inc_$low'));
    await settle(t);
    expect(env.repo.log, contains('updateItem:quantity=2,checked=null'));

    expect(t.widget<IconButton>(byKey('qty_inc_$high')).onPressed, isNull);
    expect(t.widget<IconButton>(byKey('qty_dec_$high')).onPressed, isNotNull);
  });

  listsTest('swipe-delete an item shows undo; Annuler re-adds it', (t) async {
    final env = newEnv();
    final listId = await real(t, () => env.repo.createList('Courses'));
    final id = await real(
        t, () => env.repo.addItem(listId, text: 'Savon', quantity: 3));
    await pumpApp(t, env, ListDetailScreen(listId: listId));
    expect(find.text('Savon'), findsOneWidget);

    await t.drag(byKey('item_$id'), const Offset(-800, 0));
    await t.pumpAndSettle();
    await settle(t);
    expect(find.text('Savon'), findsNothing);
    expect(find.text('Article supprimé'), findsOneWidget);

    await t.tap(find.text('Annuler'));
    await settle(t);
    expect(env.repo.log, contains('addItem:Savon::3'));
    expect(find.text('Savon'), findsOneWidget);
  });

  listsTest('add to list from an offer, button only with the callback',
      (t) async {
    final env = newEnv();
    await real(t, () => env.repo.createList('Semaine'));
    final item = OfferWithProduct(
      offer: offer(1, flyerId: 1, productId: 5),
      product: product(5, name: 'Riz'),
    );
    await pumpApp(
      t,
      env,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AddToListSheet.show(context, item),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.text('Semaine'));
    await settle(t);
    expect(env.repo.log, contains('addItem:5:Riz 5:1'));
    expect(find.text('Ajouté à « Semaine »'), findsOneWidget);

    Widget detail(VoidCallback? cb) => MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OfferDetailSheet(item: item, onAddToList: cb)),
        );
    await t.pumpWidget(detail(null));
    expect(find.text('Ajouter à une liste'), findsNothing);
    await t.pumpWidget(detail(() {}));
    expect(find.text('Ajouter à une liste'), findsOneWidget);
  });

  listsTest('unknown list id shows the EmptyState', (t) async {
    final env = newEnv();
    await pumpApp(t, env, const ListDetailScreen(listId: 'nope'));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Liste introuvable'), findsOneWidget);
  });

  listsTest('no overflow at 320 dp and text scale 2.0', (t) async {
    final env = newEnv();
    final name = 'Courses de la grande fête de fin d\'année ' * 2;
    final listId = await real(t, () => env.repo.createList(name.trim()));
    await real(
        t,
        () => env.repo.addItem(listId,
            text:
                'Un article au nom très très long pour tester le retour à la ligne',
            quantity: 12));
    await pumpApp(t, env, const ListsScreen(),
        scale: 2.0, size: const Size(320, 640));
    expect(t.getSize(find.byType(Scaffold).first).width, 320);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await pumpApp(t, env, ListDetailScreen(listId: listId),
        scale: 2.0, size: const Size(320, 640));
    expect(t.getSize(find.byType(Scaffold).first).width, 320);
    expect(t.takeException(), isNull);
  });
}
