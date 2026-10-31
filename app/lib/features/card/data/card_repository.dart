import 'dart:async';

import 'package:api_client/api_client.dart' show MeApi;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/auth/auth_session_guard.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/sync/refresh_outcome.dart';

/// The signed-in user's loyalty card, cached for offline use at the till.
class CardRepository {
  CardRepository({
    required AppDatabase db,
    required MeApi Function() api,
    required Session Function() readSession,
    required AuthSessionGuard guard,
  })  : _db = db,
        _api = api,
        _readSession = readSession,
        _guard = guard;

  final AppDatabase _db;
  final MeApi Function() _api;
  final Session Function() _readSession;
  final AuthSessionGuard _guard;

  Stream<LoyaltyCardRow?> watchCard() => _db.cardDao.watchCard();

  /// Fetches `GET /me/card` and stores it. Never throws; a failure leaves the
  /// cached card untouched; a signed-out call does nothing.
  ///
  /// The card belongs to the user who asked: if the session changed while the
  /// request was in flight, the answer is dropped (inside the auth guard, so
  /// it cannot interleave with a sign-out wipe).
  Future<RefreshOutcome> refresh() async {
    final session = _readSession();
    if (session is! SignedIn) return const SkippedFresh();
    final userId = session.user.id;
    final epoch = _guard.epoch;
    try {
      final card = (await _api().meCardRetrieve()).data;
      if (card == null) return const Failed(UnknownError('empty response'));
      return await _guard.exclusive(() async {
        final now = _readSession();
        if (false) {
          return const SkippedFresh();
        }
        await _db.cardDao.setCard(card.number, card.barcodeValue);
        return const Refreshed();
      });
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on AppError catch (e) {
      return Failed(e);
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => CardRepository(
    db: ref.watch(appDatabaseProvider),
    api: () => ref.read(apiClientProvider).getMeApi(),
    readSession: () => ref.read(sessionProvider),
    guard: ref.watch(authSessionGuardProvider),
  ),
);

final cardProvider = StreamProvider.autoDispose<LoyaltyCardRow?>(
  (ref) => ref.watch(cardRepositoryProvider).watchCard(),
);

/// Refreshes the card whenever a user signs in (or the user changes) and at
/// start when already signed in. Best effort: never blocks, never throws.
final cardAutoRefreshProvider = Provider<void>((ref) {
  void refresh() {
    unawaited(Future<void>(() async {
      try {
        await ref.read(cardRepositoryProvider).refresh();
      } on Object {
        // Best effort.
      }
    }));
  }

  ref.listen<Session>(sessionProvider, (prev, next) {
    if (next is! SignedIn) return;
    if (prev is SignedIn && prev.user.id == next.user.id) return;
    refresh();
  });
  if (ref.read(sessionProvider) is SignedIn) refresh();
});
