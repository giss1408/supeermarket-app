//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'product_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProductSummary {
  /// Returns a new [ProductSummary] instance.
  ProductSummary({
    required this.id,
    required this.name,
    this.unit,
    required this.image,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'name',
    required: true,
    includeIfNull: false,
  )
  final String name;

  @JsonKey(
    name: r'unit',
    required: false,
    includeIfNull: false,
  )
  final String? unit;

  @JsonKey(
    name: r'image',
    required: true,
    includeIfNull: true,
  )
  final String? image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductSummary &&
          other.id == id &&
          other.name == name &&
          other.unit == unit &&
          other.image == image;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      unit.hashCode +
      (image == null ? 0 : image.hashCode);

  factory ProductSummary.fromJson(Map<String, dynamic> json) =>
      _$ProductSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ProductSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
