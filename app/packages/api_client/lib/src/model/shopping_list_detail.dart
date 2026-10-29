//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/list_item.dart';
import 'package:json_annotation/json_annotation.dart';

part 'shopping_list_detail.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ShoppingListDetail {
  /// Returns a new [ShoppingListDetail] instance.
  ShoppingListDetail({
    required this.id,
    required this.name,
    required this.items,
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
    name: r'name',
    required: true,
    includeIfNull: false,
  )
  final String name;

  @JsonKey(
    name: r'items',
    required: true,
    includeIfNull: false,
  )
  final List<ListItem> items;

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
      other is ShoppingListDetail &&
          other.id == id &&
          other.name == name &&
          other.items == items &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      items.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory ShoppingListDetail.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ShoppingListDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
