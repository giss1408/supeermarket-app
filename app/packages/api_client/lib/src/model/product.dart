//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/category.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Product {
  /// Returns a new [Product] instance.
  Product({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.unit,
    required this.category,
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
    name: r'image',
    required: false,
    includeIfNull: false,
  )
  final String? image;

  @JsonKey(
    name: r'unit',
    required: false,
    includeIfNull: false,
  )
  final String? unit;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
  )
  final Category category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.image == image &&
          other.unit == unit &&
          other.category == category;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      description.hashCode +
      (image == null ? 0 : image.hashCode) +
      unit.hashCode +
      category.hashCode;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
