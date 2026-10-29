import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/ui/payment_provider.dart';

void main() {
  test('fromApi / apiValue round trip', () {
    for (final v in ['wave', 'orange_money', 'mtn_momo']) {
      expect(PaymentProvider.fromApi(v).apiValue, v);
    }
    expect(PaymentProvider.fromApi('wave'), PaymentProvider.wave);
    expect(
        PaymentProvider.fromApi('orange_money'), PaymentProvider.orangeMoney);
    expect(PaymentProvider.fromApi('mtn_momo'), PaymentProvider.mtnMomo);
  });
  test('unknown throws FormatException', () {
    expect(() => PaymentProvider.fromApi('paypal'), throwsFormatException);
    expect(() => PaymentProvider.fromApi(''), throwsFormatException);
  });
  test('display names', () {
    expect(PaymentProvider.wave.displayName, 'Wave');
    expect(PaymentProvider.orangeMoney.displayName, 'Orange Money');
    expect(PaymentProvider.mtnMomo.displayName, 'MTN MoMo');
  });
}
