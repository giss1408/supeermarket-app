import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_controller.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../errors/app_error.dart';
import '../util/clock.dart';
import 'connectivity_monitor.dart';
import 'lists_api.dart';
import 'lists_puller.dart';
import 'lists_reconciler.dart';
import 'outbox_pusher.dart';
import 'outbox_repository.dart';

sealed class SyncStatus {
  const SyncStatus();
}

final class SyncIdle extends SyncStatus {
  const SyncIdle();
}

final class SyncSyncing extends SyncStatus {
  const SyncSyncing();
}

final class SyncOffline extends SyncStatus {
  const SyncOffline();
}

final class SyncFailed extends SyncStatus {
  const SyncFailed(this.error);
  final AppError error;
}

const _debounce = Duration(milliseconds: 500);
const _backoffBase = Duration(seconds: 2);
const _backoffCap = Duration(minutes: 5);

/// 2 s, 4 s, 8 s ... capped at 5 minutes.
Duration backoffDelay(int attempt) {
  var d = _backoffBase;
  for (var i = 0; i < attempt && d < _backoffCap; i++) {
    d *= 2;
  }
  return d < _backoffCap ? d : _backoffCap;
}

/// Runs push -> pull -> reconcile, one run at a time.
class SyncCoordinator with WidgetsBindingObserver {
  SyncCoordinator({
    required AppDatabase db,
    required ListsApi Function() api,
    required Clock clock,
    required ConnectivityMonitor connectivity,
    required Session Function() readSession,
    required void Function(SyncRejection) onRejection,
    void Function(SyncStatus)? onStatus,
    this.observeLifecycle = true,
  })  : _db = db,
        _clock = clock,
        _apiFactory = api,
        _onRejection = onRejection,
        _connectivity = connectivity,
        _readSession = readSession,
        _onStatus = onStatus;

  final AppDatabase _db;
  final ConnectivityMonitor _connectivity;
  final Session Function() _readSession;
  final void Function(SyncStatus)? _onStatus;
  final bool observeLifecycle;
  final Clock _clock;
  final ListsApi Function() _apiFactory;
  final void Function(SyncRejection) _onRejection;

  // Built on first use so that a guest session never touches the API client.
  late final OutboxRepository _outbox = OutboxRepository(_db, _clock);
  late final ListsApi _api = _apiFactory();
  late final OutboxPusher _pusher = OutboxPusher(
    db: _db,
    api: _api,
    outbox: _outbox,
    onRejection: _onRejection,
  );
  late final ListsPuller _puller =
      ListsPuller(db: _db, api: _api, clock: _clock);
  late final ListsReconciler _reconciler = ListsReconciler(db: _db, api: _api);

  Future<void>? _running;
  bool _rerun = false;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connSub;
  bool _started = false;
  bool _online = true;
  int _failures = 0;
  SyncStatus _status = const SyncIdle();

  SyncStatus get status => _status;

  void _set(SyncStatus s) {
    _status = s;
    _onStatus?.call(s);
  }

  /// Call once after the session was restored.
  void start() {
    if (_started) return;
    _started = true;
    _connSub = _connectivity.changes.listen((online) {
      final regained = online && !_online;
      _online = online;
      if (regained) _retryNow();
    });
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _retryNow();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _connSub?.cancel();
    if (observeLifecycle && _started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retryNow();
  }

  /// Session changed (sign-in, sign-out, account switch).
  void onSessionChanged(Session session) {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _failures = 0;
    if (session is SignedIn) {
      _retryNow();
    } else {
      _set(const SyncIdle());
    }
  }

  /// After a local mutation: coalesce bursts into one run.
  void requestSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _retryNow);
  }

  void _retryNow() {
    _retryTimer?.cancel();
    if (_running != null) {
      _rerun = true;
      return;
    }
    unawaited(run());
  }

  /// Single-flight: a call while a run is active returns the same Future.
  Future<void> run({bool force = false}) {
    final current = _running;
    if (current != null) return current;
    final future = _run(force).whenComplete(() {
      _running = null;
      if (_rerun) {
        _rerun = false;
        if (_readSession() is SignedIn) unawaited(run());
      }
    });
    _running = future;
    return future;
  }

  Future<void> _run(bool force) async {
    final session = _readSession();
    if (session is! SignedIn) return;
    final userId = session.user.id;
    bool active() {
      final s = _readSession();
      return s is SignedIn && s.user.id == userId;
    }

    if (!force && !await _connectivity.isOnline()) {
      _online = false;
      if (active()) _set(const SyncOffline());
      return;
    }
    _online = true;
    _retryTimer?.cancel();
    _set(const SyncSyncing());
    try {
      await _outbox.recoverInterrupted();
      if (!active()) return;
      // Pushing again after the pull/reconcile picks up edits made meanwhile.
      for (var round = 0; round < 3; round++) {
        final outcome = await _pusher.push(isActive: active);
        if (!active() || outcome == PushOutcome.aborted) return;
        if (outcome == PushOutcome.unauthorized) {
          _set(const SyncFailed(
            ApiError(code: 'not_authenticated', status: 401, fields: {}),
          ));
          return;
        }
        if (outcome == PushOutcome.retryLater) {
          // No pull while an op is stuck: a half-sent create must be adopted,
          // not duplicated by a pull.
          _scheduleRetry(const NetworkError());
          return;
        }
        if (round == 0) {
          await _puller.pull(isActive: active);
          if (!active()) return;
          await _reconciler.reconcile(isActive: active);
          if (!active()) return;
        }
        if (await _db.outboxDao.pendingCount() == 0) break;
      }
      _failures = 0;
      _set(const SyncIdle());
    } on Object catch (e) {
      if (!active()) return;
      final error = e is AppError ? e : UnknownError(e);
      _scheduleRetry(error);
    }
  }

  void _scheduleRetry(AppError error) {
    _set(
      error is NetworkError || error is AppTimeoutError
          ? const SyncOffline()
          : SyncFailed(error),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(backoffDelay(_failures), _retryNow);
    _failures++;
  }
}

final syncRejectionSinkProvider =
    Provider<StreamController<SyncRejection>>((ref) {
  final c = StreamController<SyncRejection>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Changes the server refused (for the UI to tell the user).
final syncRejectionsProvider = Provider<Stream<SyncRejection>>(
  (ref) => ref.watch(syncRejectionSinkProvider).stream,
);

final syncStatusProvider = StateProvider<SyncStatus>((ref) => const SyncIdle());

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final sink = ref.watch(syncRejectionSinkProvider);
  final coordinator = SyncCoordinator(
    db: ref.watch(appDatabaseProvider),
    api: () => ref.read(listsApiProvider),
    clock: ref.watch(clockProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    readSession: () => ref.read(sessionProvider),
    onRejection: (r) {
      if (!sink.isClosed) sink.add(r);
    },
    onStatus: (s) {
      // Deferred: a status can be set while a provider is being built.
      Future<void>.microtask(() {
        try {
          ref.read(syncStatusProvider.notifier).state = s;
        } on Object {
          // Container disposed.
        }
      });
    },
  );
  ref.listen<Session>(
    sessionProvider,
    (_, next) => coordinator.onSessionChanged(next),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
