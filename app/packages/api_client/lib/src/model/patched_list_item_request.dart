//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'patched_list_item_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedListItemRequest {
  /// Returns a new [PatchedListItemRequest] instance.
  PatchedListItemRequest({
    this.product,
    this.text,
    this.quantity,
    this.checked,
  });

  @JsonKey(
    name: r'product',
    required: false,
    includeIfNull: false,
  )
  final int? product;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedListItemRequest &&
          other.product == product &&
          other.text == text &&
          other.quantity == quantity &&
          other.checked == checked;

  @override
  int get hashCode =>
      (product == null ? 0 : product.hashCode) +
      text.hashCode +
      quantity.hashCode +
      checked.hashCode;

  factory PatchedListItemRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedListItemRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedListItemRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
