import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const minQuantity = 1;
const maxQuantity = 999;

/// - [value] + with 48 dp buttons, clamped to 1..999.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.idSuffix = '',
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// Appended to the button keys (`qty_dec_<id>`, `qty_inc_<id>`).
  final String idSuffix;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const box = BoxConstraints.tightFor(width: 48, height: 48);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('qty_dec_$idSuffix'),
          constraints: box,
          tooltip: l.quantityDecrease,
          icon: const Icon(Icons.remove),
          onPressed: value > minQuantity ? () => onChanged(value - 1) : null,
        ),
        Semantics(
          label: l.quantityValue(value),
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          key: Key('qty_inc_$idSuffix'),
          constraints: box,
          tooltip: l.quantityIncrease,
          icon: const Icon(Icons.add),
          onPressed: value < maxQuantity ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
