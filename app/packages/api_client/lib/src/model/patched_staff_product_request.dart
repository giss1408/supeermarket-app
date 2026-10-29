//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'patched_staff_product_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedStaffProductRequest {
  /// Returns a new [PatchedStaffProductRequest] instance.
  PatchedStaffProductRequest({
    this.name,
    this.description,
    this.category,
    this.unit,
    this.ean,
    this.imageName,
  });

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    name: r'description',
    required: false,
    includeIfNull: false,
  )
  final String? description;

  @JsonKey(
    name: r'category',
    required: false,
    includeIfNull: false,
  )
  final int? category;

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
    name: r'image_name',
    required: false,
    includeIfNull: false,
  )
  final String? imageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedStaffProductRequest &&
          other.name == name &&
          other.description == description &&
          other.category == category &&
          other.unit == unit &&
          other.ean == ean &&
          other.imageName == imageName;

  @override
  int get hashCode =>
      name.hashCode +
      description.hashCode +
      category.hashCode +
      unit.hashCode +
      (ean == null ? 0 : ean.hashCode) +
      (imageName == null ? 0 : imageName.hashCode);

  factory PatchedStaffProductRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedStaffProductRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedStaffProductRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
