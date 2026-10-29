//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'shopping_list_detail_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ShoppingListDetailRequest {
  /// Returns a new [ShoppingListDetailRequest] instance.
  ShoppingListDetailRequest({
    required this.name,
  });

  @JsonKey(
    name: r'name',
    required: true,
    includeIfNull: false,
  )
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingListDetailRequest && other.name == name;

  @override
  int get hashCode => name.hashCode;

  factory ShoppingListDetailRequest.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListDetailRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ShoppingListDetailRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
