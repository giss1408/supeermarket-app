import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/util/clock.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(
    dio: ref.watch(dioProvider),
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final paymentMethodsProvider = StreamProvider<List<PaymentMethodRow>>(
  (ref) => ref.watch(paymentRepositoryProvider).watchMethods(),
);

final paymentLastCheckedProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(paymentRepositoryProvider).watchLastChecked(),
);

sealed class PaymentRefreshState {
  const PaymentRefreshState();
}

final class Idle extends PaymentRefreshState {
  const Idle();
}

final class Loading extends PaymentRefreshState {
  const Loading();
}

final class Done extends PaymentRefreshState {
  const Done(this.at);
  final DateTime at;
}

final class FailedState extends PaymentRefreshState {
  const FailedState(this.error);
  final AppError error;
}

class PaymentRefreshController extends Notifier<PaymentRefreshState> {
  var _disposed = false;

  @override
  PaymentRefreshState build() {
    ref.onDispose(() => _disposed = true);
    return const Idle();
  }

  Future<void> refresh() async {
    state = const Loading();
    PaymentRefreshResult result;
    try {
      result = await ref.read(paymentRepositoryProvider).refresh();
    } on Object catch (e) {
      result = Failed(e is AppError ? e : UnknownError(e));
    }
    if (_disposed) return;
    state = switch (result) {
      Refreshed(:final at) => Done(at),
      Failed(:final error) => FailedState(error),
    };
  }
}

final paymentRefreshProvider =
    NotifierProvider<PaymentRefreshController, PaymentRefreshState>(
  PaymentRefreshController.new,
);
