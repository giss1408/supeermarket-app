//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'patched_shopping_list_detail_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedShoppingListDetailRequest {
  /// Returns a new [PatchedShoppingListDetailRequest] instance.
  PatchedShoppingListDetailRequest({
    this.name,
  });

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedShoppingListDetailRequest && other.name == name;

  @override
  int get hashCode => name.hashCode;

  factory PatchedShoppingListDetailRequest.fromJson(
          Map<String, dynamic> json) =>
      _$PatchedShoppingListDetailRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchedShoppingListDetailRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
