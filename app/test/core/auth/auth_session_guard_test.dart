import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/auth_session_guard.dart';

void main() {
  test('invalidate_is_synchronous_and_monotonic', () {
    final g = AuthSessionGuard();
    expect(g.epoch, 0);
    expect(g.invalidate(), 1);
    expect(g.epoch, 1);
    expect(g.invalidate(), 2);
    expect(g.epoch, 2);
  });

  test('exclusive_serialises_in_call_order', () async {
    final g = AuthSessionGuard();
    final log = <String>[];
    final gate = Completer<void>();
    final a = g.exclusive(() async {
      log.add('a:start');
      await gate.future;
      log.add('a:end');
    });
    final b = g.exclusive(() async {
      log.add('b:start');
      log.add('b:end');
    });
    await Future<void>.delayed(Duration.zero);
    expect(log, ['a:start'], reason: 'b waits for a');
    gate.complete();
    await Future.wait([a, b]);
    expect(log, ['a:start', 'a:end', 'b:start', 'b:end']);
  });

  test('exclusive_returns_value_propagates_error_and_releases_the_lock',
      () async {
    final g = AuthSessionGuard();
    expect(await g.exclusive(() async => 42), 42);
    await expectLater(
      g.exclusive<void>(() async => throw StateError('boom')),
      throwsStateError,
    );
    // The lock was released: the next section runs, and the error did not
    // leak into it.
    expect(await g.exclusive(() async => 'ok'), 'ok');
  });

  test('a_failing_section_does_not_fail_queued_sections', () async {
    final g = AuthSessionGuard();
    final first = g.exclusive<void>(() async => throw StateError('x'));
    final second = g.exclusive(() async => 7);
    await expectLater(first, throwsStateError);
    expect(await second, 7);
  });
}
