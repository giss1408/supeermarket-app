//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'patched_staff_category_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedStaffCategoryRequest {
  /// Returns a new [PatchedStaffCategoryRequest] instance.
  PatchedStaffCategoryRequest({
    this.name,
    this.slug,
    this.sortOrder,
  });

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    name: r'slug',
    required: false,
    includeIfNull: false,
  )
  final String? slug;

  // minimum: -2147483648
  // maximum: 2147483647
  @JsonKey(
    name: r'sort_order',
    required: false,
    includeIfNull: false,
  )
  final int? sortOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedStaffCategoryRequest &&
          other.name == name &&
          other.slug == slug &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode => name.hashCode + slug.hashCode + sortOrder.hashCode;

  factory PatchedStaffCategoryRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedStaffCategoryRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedStaffCategoryRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
