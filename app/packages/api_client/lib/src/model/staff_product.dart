//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'staff_product.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffProduct {
  /// Returns a new [StaffProduct] instance.
  StaffProduct({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.unit,
    this.ean,
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
    name: r'description',
    required: false,
    includeIfNull: false,
  )
  final String? description;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
  )
  final int category;

  @JsonKey(
    name: r'unit',
    required: false,
    includeIfNull: false,
  )
  final String? unit;

  /// 8 or 13 digits; empty string or null for none
  @JsonKey(
    name: r'ean',
    required: false,
    includeIfNull: false,
  )
  final String? ean;

  @JsonKey(
    name: r'image',
    required: true,
    includeIfNull: true,
  )
  final String? image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffProduct &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.category == category &&
          other.unit == unit &&
          other.ean == ean &&
          other.image == image;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      description.hashCode +
      category.hashCode +
      unit.hashCode +
      (ean == null ? 0 : ean.hashCode) +
      (image == null ? 0 : image.hashCode);

  factory StaffProduct.fromJson(Map<String, dynamic> json) =>
      _$StaffProductFromJson(json);

  Map<String, dynamic> toJson() => _$StaffProductToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
