//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/staff_product.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_staff_product_list.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedStaffProductList {
  /// Returns a new [PaginatedStaffProductList] instance.
  PaginatedStaffProductList({
    this.next,
    this.previous,
    required this.results,
  });

  @JsonKey(
    name: r'next',
    required: false,
    includeIfNull: false,
  )
  final String? next;

  @JsonKey(
    name: r'previous',
    required: false,
    includeIfNull: false,
  )
  final String? previous;

  @JsonKey(
    name: r'results',
    required: true,
    includeIfNull: false,
  )
  final List<StaffProduct> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedStaffProductList &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedStaffProductList.fromJson(Map<String, dynamic> json) =>
      _$PaginatedStaffProductListFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedStaffProductListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
