//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'staff_category.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffCategory {
  /// Returns a new [StaffCategory] instance.
  StaffCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.sortOrder,
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
    name: r'slug',
    required: true,
    includeIfNull: false,
  )
  final String slug;

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
      other is StaffCategory &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      id.hashCode + name.hashCode + slug.hashCode + sortOrder.hashCode;

  factory StaffCategory.fromJson(Map<String, dynamic> json) =>
      _$StaffCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$StaffCategoryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
