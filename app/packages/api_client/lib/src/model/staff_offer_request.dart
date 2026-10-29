//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'staff_offer_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffOfferRequest {
  /// Returns a new [StaffOfferRequest] instance.
  StaffOfferRequest({
    required this.flyer,
    required this.product,
    required this.price,
    this.oldPrice,
    this.badgeText,
    this.sortOrder,
    this.validFrom,
    this.validTo,
  });

  @JsonKey(
    name: r'flyer',
    required: true,
    includeIfNull: false,
  )
  final int flyer;

  @JsonKey(
    name: r'product',
    required: true,
    includeIfNull: false,
  )
  final int product;

  @JsonKey(
    name: r'price',
    required: true,
    includeIfNull: false,
  )
  final String price;

  @JsonKey(
    name: r'old_price',
    required: false,
    includeIfNull: false,
  )
  final String? oldPrice;

  @JsonKey(
    name: r'badge_text',
    required: false,
    includeIfNull: false,
  )
  final String? badgeText;

  // minimum: -2147483648
  // maximum: 2147483647
  @JsonKey(
    name: r'sort_order',
    required: false,
    includeIfNull: false,
  )
  final int? sortOrder;

  @JsonKey(
    name: r'valid_from',
    required: false,
    includeIfNull: false,
  )
  final DateTime? validFrom;

  @JsonKey(
    name: r'valid_to',
    required: false,
    includeIfNull: false,
  )
  final DateTime? validTo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffOfferRequest &&
          other.flyer == flyer &&
          other.product == product &&
          other.price == price &&
          other.oldPrice == oldPrice &&
          other.badgeText == badgeText &&
          other.sortOrder == sortOrder &&
          other.validFrom == validFrom &&
          other.validTo == validTo;

  @override
  int get hashCode =>
      flyer.hashCode +
      product.hashCode +
      price.hashCode +
      (oldPrice == null ? 0 : oldPrice.hashCode) +
      badgeText.hashCode +
      sortOrder.hashCode +
      (validFrom == null ? 0 : validFrom.hashCode) +
      (validTo == null ? 0 : validTo.hashCode);

  factory StaffOfferRequest.fromJson(Map<String, dynamic> json) =>
      _$StaffOfferRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StaffOfferRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
