/// Mobile-money providers supported for payments.
enum PaymentProvider {
  wave('wave', 'Wave'),
  orangeMoney('orange_money', 'Orange Money'),
  mtnMomo('mtn_momo', 'MTN MoMo');

  const PaymentProvider(this.apiValue, this.displayName);

  /// Value used by the API.
  final String apiValue;

  /// Plain-text name (no logos: these are trademarks).
  final String displayName;

  /// Parses an API value; throws [FormatException] when unknown.
  static PaymentProvider fromApi(String value) {
    for (final p in values) {
      if (p.apiValue == value) return p;
    }
    throw FormatException('Unknown payment provider', value);
  }
}
