import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart' as keys;
import 'package:supermarket_app/core/router/routes.dart';

import '../../core/db/test_db.dart';
import '../../support/account_harness.dart';
import '../../support/fake_http.dart';

Session sessionOf(AccountEnv env) => env.h.container.read(sessionProvider);

/// Local data of the signed-in user: a list, a card and [pending] outbox ops.
Future<void> seed(AccountEnv env, {int pending = 0}) => env.real(() async {
      final db = env.h.db;
      await db.listsDao.upsertList(shoppingList('l1'));
      await db.listsDao.upsertItem(listItem('i1', 'l1'));
      await db.cardDao.setCard('123456', '123456');
      // Public data must survive a wipe.
      await db.publicDao.replaceCurrentFlyer(flyer(1, current: true), [], []);
      await db.paymentDao.replaceMethods([
        const PaymentMethodRow(
          provider: 'wave',
          phoneNumber: '+225',
          displayName: 'Wave',
          instructions: 'x',
          updatedAt: '2026-10-29T20:10:13.725480Z',
        ),
      ]);
      for (var i = 0; i < pending; i++) {
        await db.outboxDao.enqueue(op('createList'));
      }
    });

Future<Map<String, int>> counts(AccountEnv env) => env.real(env.h.counts);

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await settle(t);
}

const wiped = {
  'lists': 0,
  'items': 0,
  'outbox': 0,
  'card': 0,
  'flyers': 1,
  'payments': 1,
};

void main() {
  group('account screen', () {
    screenTest('guest_sees_sign_in_prompt_and_pay_entry', (t) async {
      final env = await AccountEnv.create(t);
      await env.pump(t);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Payer par mobile money'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsNothing);
      await tapText(t, 'Payer par mobile money');
      expect(env.location, Routes.pay);
    });

    screenTest('signed_in_shows_name_email_and_tiles', (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await env.pump(t);
      expect(find.text('Awa Koné'), findsOneWidget);
      expect(find.text('u1@example.ci'), findsOneWidget);
      for (final tile in [
        'Ma carte de fidélité',
        'Payer par mobile money',
        'Modifier mon nom',
        'Se déconnecter',
        'Supprimer mon compte',
      ]) {
        expect(find.text(tile), findsOneWidget, reason: tile);
      }
      expect(find.text('Se connecter'), findsNothing);
      await tapText(t, 'Ma carte de fidélité');
      expect(env.location, Routes.card);
    });
  });

  group('sign out', () {
    screenTest('without_pending_ops_signs_out_and_wipes_user_data', (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env);
      env.h.http.reply('POST', '/auth/logout', 200, {});
      await env.pump(t);
      await tapText(t, 'Se déconnecter');
      expect(find.byType(AlertDialog), findsNothing);
      expect(sessionOf(env), isA<Guest>());
      expect(env.h.store.refresh, isNull);
      expect(env.h.store.user, isNull);
      expect(await counts(env), wiped);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(env.location, Routes.account);
    });

    screenTest('with_pending_ops_warns_and_cancel_changes_nothing', (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env, pending: 2);
      await env.pump(t);
      await tapText(t, 'Se déconnecter');
      expect(
        find.text("2 modifications n'ont pas encore été envoyées"),
        findsOneWidget,
      );
      expect(find.text("Synchroniser d'abord"), findsOneWidget);
      await tapText(t, 'Annuler');
      expect(find.byType(AlertDialog), findsNothing);
      expect(sessionOf(env), isA<SignedIn>());
      expect(env.h.store.refresh, 'refresh-1');
      expect((await counts(env))['outbox'], 2);
      expect(env.h.http.callsTo('/auth/logout'), isEmpty);
    });

    screenTest('one_pending_op_uses_the_singular', (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env, pending: 1);
      await env.pump(t);
      await tapText(t, 'Se déconnecter');
      expect(
        find.text("1 modification n'a pas encore été envoyée"),
        findsOneWidget,
      );
    });

    screenTest('discard_asks_again_then_signs_out_and_wipes_the_outbox',
        (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env, pending: 1);
      env.h.http.reply('POST', '/auth/logout', 200, {});
      await env.pump(t);
      await tapText(t, 'Se déconnecter');
      await tapText(t, 'Abandonner les modifications');
      // Destructive confirmation: nothing happened yet.
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(sessionOf(env), isA<SignedIn>());
      await tapText(t, 'Abandonner et me déconnecter');
      expect(sessionOf(env), isA<Guest>());
      expect(await counts(env), wiped);
      expect(env.location, Routes.account);
    });
  });

  group('delete account', () {
    screenTest('confirm_calls_delete_wipes_everything_and_lands_on_offers',
        (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env, pending: 1);
      env.h.http.reply('DELETE', '/api/v1/me', 204);
      await env.pump(t);
      await tapText(t, 'Supprimer mon compte');
      expect(find.textContaining('définitivement'), findsWidgets);
      expect(
          env.h.http.callsTo('/api/v1/me').where((c) => c.method == 'DELETE'),
          isEmpty);
      await tapText(t, 'Supprimer définitivement');
      expect(
        env.h.http.calls.where((c) => c.method == 'DELETE'),
        hasLength(1),
      );
      expect(sessionOf(env), isA<Guest>());
      expect(env.h.store.refresh, isNull);
      expect(await counts(env), wiped);
      expect(
        await env.real(() => env.h.db.syncMetaDao.get(keys.lastUserId)),
        isNull,
      );
      // No server logout: the account is gone.
      expect(env.h.http.callsTo('/auth/logout'), isEmpty);
      expect(env.location, Routes.offers);
      expect(find.text('PAGE_OFFERS'), findsOneWidget);
      expect(find.text('Votre compte a été supprimé'), findsOneWidget);
    });

    screenTest('cancel_does_nothing', (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await env.pump(t);
      await tapText(t, 'Supprimer mon compte');
      await tapText(t, 'Annuler');
      expect(sessionOf(env), isA<SignedIn>());
      expect(env.h.http.calls.where((c) => c.method == 'DELETE'), isEmpty);
    });

    screenTest('offline_failure_changes_nothing_and_shows_the_error',
        (t) async {
      final env = await AccountEnv.create(t);
      await env.signIn(1);
      await seed(env, pending: 1);
      final before = await counts(env);
      env.h.http.on('DELETE', '/api/v1/me', offline());
      await env.pump(t);
      await tapText(t, 'Supprimer mon compte');
      await tapText(t, 'Supprimer définitivement');
      expect(
        find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget,
      );
      expect(sessionOf(env), isA<SignedIn>());
      expect(env.h.store.refresh, 'refresh-1');
      expect(env.h.store.user?.id, '1');
      expect(await counts(env), before);
      expect(
        await env.real(() => env.h.db.syncMetaDao.get(keys.lastUserId)),
        '1',
      );
      expect(env.location, Routes.account);
    });
  });

  group('edit name', () {
    Map<String, dynamic> me(String name) => {
          'id': 1,
          'email': 'u1@example.ci',
          'name': name,
          'role': 'customer',
        };

    Future<void> open(WidgetTester t, AccountEnv env) async {
      await env.signIn(1);
      await env.pump(t);
      await tapText(t, 'Modifier mon nom');
    }

    Future<void> submit(WidgetTester t, String text) async {
      await t.enterText(find.byKey(const Key('field_edit_name')), text);
      await t.tap(find.byKey(const Key('edit_name_submit')));
      await settle(t);
    }

    screenTest('patch_updates_session_and_persisted_user', (t) async {
      final env = await AccountEnv.create(t);
      env.h.http.reply('PATCH', '/api/v1/me', 200, me('Nouveau Nom'));
      await open(t, env);
      await submit(t, '  Nouveau Nom ');
      final patch = env.h.http.calls.singleWhere((c) => c.method == 'PATCH');
      expect(patch.body, contains('"name":"Nouveau Nom"'));
      expect((sessionOf(env) as SignedIn).user.name, 'Nouveau Nom');
      expect(env.h.store.user?.name, 'Nouveau Nom');
      expect(env.h.store.user?.email, 'u1@example.ci');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('field_edit_name')), findsNothing);
      expect(find.text('Nouveau Nom'), findsOneWidget);
    });

    screenTest('blank_name_is_refused_locally', (t) async {
      final env = await AccountEnv.create(t);
      await open(t, env);
      await submit(t, '   ');
      expect(find.text('Saisissez votre nom.'), findsOneWidget);
      expect(env.h.http.calls.where((c) => c.method == 'PATCH'), isEmpty);
    });

    screenTest('server_field_error_is_shown_under_the_field', (t) async {
      final env = await AccountEnv.create(t);
      env.h.http.reply(
        'PATCH',
        '/api/v1/me',
        400,
        errorBody('validation_error', {
          'name': ['Ce nom est invalide.'],
        }),
      );
      await open(t, env);
      await submit(t, 'X');
      expect(find.text('Ce nom est invalide.'), findsOneWidget);
      expect(find.byKey(const Key('field_edit_name')), findsOneWidget);
      expect((sessionOf(env) as SignedIn).user.name, 'Awa Koné');
      expect(env.h.store.user?.name, 'Awa Koné');
    });

    screenTest('sign_out_while_in_flight_discards_the_result', (t) async {
      final env = await AccountEnv.create(t);
      final gate = Completer<void>();
      env.h.http.on('PATCH', '/api/v1/me', (_, __) async {
        await gate.future;
        return FakeResponse(200, me('Intrus'));
      });
      env.h.http.reply('POST', '/auth/logout', 200, {});
      await open(t, env);
      await submit(t, 'Intrus');
      await env.real(() => env.h.session.signOut(discardUnsynced: true));
      env.h.store.log.clear();
      gate.complete();
      await settle(t);
      expect(sessionOf(env), isA<Guest>());
      expect(env.h.store.user, isNull);
      expect(env.h.store.refresh, isNull);
      expect(env.h.store.log, isEmpty, reason: 'nothing may be written');
    });
  });

  screenTest('overflow_smoke_320dp_text_scale_2', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await AccountEnv.create(t);
    env.h.stubLogin();
    env.h.http.reply('GET', '/api/v1/me', 200, {
      'id': 1,
      'email': '${'tres.long.prenom.nom' * 3}@example-entreprise.ci',
      'name': 'Marie-Ange Kouassi-Yao ${'Nom' * 12}',
      'role': 'customer',
    });
    await env.real(() => env.h.session.signIn('a@b.ci', 'pw'));
    await env
        .real(() => env.h.db.cardDao.setCard('0419095719373', '0419095719373'));
    await env.pump(t);
    expect(t.getSize(find.byType(Scaffold).first).width, 320);
    expect(t.takeException(), isNull);
    env.router.go(Routes.card);
    await settle(t);
    expect(t.getSize(find.byType(Scaffold).first).width, 320);
    expect(find.text('0419 0957 1937 3'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
