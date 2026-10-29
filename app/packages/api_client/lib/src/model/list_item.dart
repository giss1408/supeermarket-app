//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/product_summary.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_item.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListItem {
  /// Returns a new [ListItem] instance.
  ListItem({
    required this.id,
    required this.product,
    this.text,
    this.quantity,
    this.checked,
    required this.createdAt,
    required this.updatedAt,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'product',
    required: true,
    includeIfNull: true,
  )
  final ProductSummary? product;

  @JsonKey(
    name: r'text',
    required: false,
    includeIfNull: false,
  )
  final String? text;

  // minimum: 1
  // maximum: 999
  @JsonKey(
    name: r'quantity',
    required: false,
    includeIfNull: false,
  )
  final int? quantity;

  @JsonKey(
    name: r'checked',
    required: false,
    includeIfNull: false,
  )
  final bool? checked;

  @JsonKey(
    name: r'created_at',
    required: true,
    includeIfNull: false,
  )
  final DateTime createdAt;

  @JsonKey(
    name: r'updated_at',
    required: true,
    includeIfNull: false,
  )
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItem &&
          other.id == id &&
          other.product == product &&
          other.text == text &&
          other.quantity == quantity &&
          other.checked == checked &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      (product == null ? 0 : product.hashCode) +
      text.hashCode +
      quantity.hashCode +
      checked.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory ListItem.fromJson(Map<String, dynamic> json) =>
      _$ListItemFromJson(json);

  Map<String, dynamic> toJson() => _$ListItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
