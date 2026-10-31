import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';

import '../../support/sync_harness.dart';

void main() {
  test('sync_is_single_flight_and_does_nothing_for_guest', () async {
    final guest = SyncHarness(session: const Guest());
    await guest.repo.createList('A');
    await guest.sync();
    expect(guest.api.calls, isEmpty);

    final h = SyncHarness();
    await h.repo.createList('A');
    final gate = Completer<void>();
    h.api.onCall =
        (c) => c.startsWith('createList') ? gate.future : Future.value();
    final first = h.coordinator.run();
    await pumpEventQueue();
    final second = h.coordinator.run();
    expect(identical(first, second), isTrue);
    gate.complete();
    await first;
    expect(h.api.count('createList'), 1);
    expect(h.api.maxConcurrent, 1);
  });

  test('a_sign_out_or_account_switch_mid_run_aborts_without_writing_results',
      () async {
    // Sign-out (data wiped) while the create is in flight.
    final h = SyncHarness();
    await h.repo.createList('A');
    var gate = Completer<void>();
    h.api.onCall =
        (c) => c.startsWith('createList') ? gate.future : Future.value();
    var run = h.sync();
    await pumpEventQueue();
    h.session = const Guest();
    await h.db.wipeUserData();
    gate.complete();
    await run;
    expect(await h.lists(), isEmpty);
    expect(await h.ops(), isEmpty);
    expect(await h.lastPull(), isNull);
    expect(h.api.writes, ['createList:A']);

    // Account switch while in flight: nothing is written for the old user.
    final s = SyncHarness();
    await s.repo.createList('B');
    gate = Completer<void>();
    s.api.onCall =
        (c) => c.startsWith('createList') ? gate.future : Future.value();
    run = s.sync();
    await pumpEventQueue();
    s.session = const SignedIn(userB);
    gate.complete();
    await run;
    expect((await s.lists()).single.remoteId, isNull);
    expect(await s.lastPull(), isNull);

    // Switch between steps (during the pull): no stamp, no reconcile.
    final p = SyncHarness();
    p.api.seedList('Serveur');
    p.api.onCall = (c) async {
      if (c.startsWith('listLists')) p.session = const SignedIn(userB);
    };
    await p.sync();
    expect(await p.lastPull(), isNull);
    expect(await p.lists(), isEmpty);
    expect(p.api.count('allListIds'), 0);
  });
}
