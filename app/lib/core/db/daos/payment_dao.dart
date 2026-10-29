import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [PaymentMethods])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<void> replaceMethods(List<PaymentMethodRow> methods) =>
      transaction(() async {
        final providers = methods.map((m) => m.provider).toList();
        await (delete(paymentMethods)
              ..where((t) => t.provider.isNotIn(providers)))
            .go();
        await batch(
            (b) => b.insertAllOnConflictUpdate(paymentMethods, methods));
      });

  Stream<List<PaymentMethodRow>> watchMethods() =>
      (select(paymentMethods)..orderBy([(t) => OrderingTerm.asc(t.provider)]))
          .watch();
}
