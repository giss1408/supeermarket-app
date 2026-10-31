import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/sync/refresh_outcome.dart';
import 'package:supermarket_app/features/card/data/card_repository.dart';

import '../../support/account_harness.dart';
import '../../support/fake_http.dart';

const _cardA = {'number': '111111', 'barcode_value': '111111'};
const _cardB = {'number': '222222', 'barcode_value': '222222'};

/// A has a list, a pending outbox op and a cached card.
Future<AccountEnv> signedInA() async {
  final env = AccountEnv.plain();
  env.h.http.reply('POST', '/auth/logout', 200, {});
  env.h.http.reply('GET', '/api/v1/me/card', 200, _cardA);
  await env.signIn(1);
  await env.h.seedData();
  await env.h.container.read(cardRepositoryProvider).refresh();
  expect((await env.h.counts())['outbox'], 1);
  expect((await env.h.db.cardDao.watchCard().first)?.number, '111111');
  return env;
}

Future<void> expectBIsClean(AccountEnv env) async {
  expect(
    (env.h.container.read(sessionProvider) as SignedIn).user.id,
    '2',
  );
  final counts = await env.h.counts();
  expect(counts['lists'], 0);
  expect(counts['items'], 0);
  expect(counts['outbox'], 0);
  expect(counts['card'], 0);
  env.h.http.reply('GET', '/api/v1/me/card', 200, _cardB);
  await env.h.container.read(cardRepositoryProvider).refresh();
  final card = await env.h.db.cardDao.watchCard().first;
  expect(card?.number, '222222');
}

void main() {
  test('b_sees_nothing_of_a_after_a_discarding_sign_out', () async {
    final env = await signedInA();
    await env.h.session.signOut(discardUnsynced: true);
    await env.signIn(2);
    await expectBIsClean(env);
  });

  test('b_sees_nothing_of_a_when_a_session_expired_before_b_signed_in',
      () async {
    final env = await signedInA();
    await env.h.session.expireSession();
    await env.signIn(2);
    await expectBIsClean(env);
  });

  test('b_sees_nothing_of_a_when_b_signs_in_without_any_sign_out', () async {
    final env = await signedInA();
    await env.signIn(2);
    await expectBIsClean(env);
  });

  test('a_card_answer_arriving_after_a_switch_is_dropped', () async {
    final env = await signedInA();
    await env.h.session.signOut(discardUnsynced: true);
    await env.signIn(1);
    final gate = Completer<void>();
    env.h.http.on('GET', '/api/v1/me/card', (_, __) async {
      await gate.future;
      return FakeResponse(200, _cardA);
    });
    final pending = env.h.container.read(cardRepositoryProvider).refresh();
    await Future<void>.delayed(Duration.zero);
    await env.h.session.expireSession();
    await env.signIn(2);
    gate.complete();
    expect(await pending, isA<SkippedFresh>());
    expect(await env.h.db.cardDao.watchCard().first, isNull);
  });
}
