//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/product.dart';
import 'package:json_annotation/json_annotation.dart';

part 'offer.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Offer {
  /// Returns a new [Offer] instance.
  Offer({
    required this.id,
    required this.flyer,
    required this.price,
    this.oldPrice,
    this.badgeText,
    this.validFrom,
    this.validTo,
    required this.product,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'flyer',
    required: true,
    includeIfNull: false,
  )
  final int flyer;

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

  @JsonKey(
    name: r'product',
    required: true,
    includeIfNull: false,
  )
  final Product product;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offer &&
          other.id == id &&
          other.flyer == flyer &&
          other.price == price &&
          other.oldPrice == oldPrice &&
          other.badgeText == badgeText &&
          other.validFrom == validFrom &&
          other.validTo == validTo &&
          other.product == product;

  @override
  int get hashCode =>
      id.hashCode +
      flyer.hashCode +
      price.hashCode +
      (oldPrice == null ? 0 : oldPrice.hashCode) +
      badgeText.hashCode +
      (validFrom == null ? 0 : validFrom.hashCode) +
      (validTo == null ? 0 : validTo.hashCode) +
      product.hashCode;

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);

  Map<String, dynamic> toJson() => _$OfferToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
