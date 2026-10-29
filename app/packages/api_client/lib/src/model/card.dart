//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'card.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Card {
  /// Returns a new [Card] instance.
  Card({
    required this.number,
    required this.barcodeValue,
  });

  @JsonKey(
    name: r'number',
    required: true,
    includeIfNull: false,
  )
  final String number;

  @JsonKey(
    name: r'barcode_value',
    required: true,
    includeIfNull: false,
  )
  final String barcodeValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card &&
          other.number == number &&
          other.barcodeValue == barcodeValue;

  @override
  int get hashCode => number.hashCode + barcodeValue.hashCode;

  factory Card.fromJson(Map<String, dynamic> json) => _$CardFromJson(json);

  Map<String, dynamic> toJson() => _$CardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
