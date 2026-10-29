//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/staff_offer.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_staff_offer_list.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedStaffOfferList {
  /// Returns a new [PaginatedStaffOfferList] instance.
  PaginatedStaffOfferList({
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
  final List<StaffOffer> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedStaffOfferList &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedStaffOfferList.fromJson(Map<String, dynamic> json) =>
      _$PaginatedStaffOfferListFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedStaffOfferListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
