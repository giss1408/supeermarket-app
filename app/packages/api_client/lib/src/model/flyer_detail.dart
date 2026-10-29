//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/offer.dart';
import 'package:json_annotation/json_annotation.dart';

part 'flyer_detail.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FlyerDetail {
  /// Returns a new [FlyerDetail] instance.
  FlyerDetail({
    required this.id,
    required this.title,
    required this.validFrom,
    required this.validTo,
    this.coverImage,
    required this.offers,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'title',
    required: true,
    includeIfNull: false,
  )
  final String title;

  @JsonKey(
    name: r'valid_from',
    required: true,
    includeIfNull: false,
  )
  final DateTime validFrom;

  @JsonKey(
    name: r'valid_to',
    required: true,
    includeIfNull: false,
  )
  final DateTime validTo;

  @JsonKey(
    name: r'cover_image',
    required: false,
    includeIfNull: false,
  )
  final String? coverImage;

  @JsonKey(
    name: r'offers',
    required: true,
    includeIfNull: false,
  )
  final List<Offer> offers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlyerDetail &&
          other.id == id &&
          other.title == title &&
          other.validFrom == validFrom &&
          other.validTo == validTo &&
          other.coverImage == coverImage &&
          other.offers == offers;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      validFrom.hashCode +
      validTo.hashCode +
      (coverImage == null ? 0 : coverImage.hashCode) +
      offers.hashCode;

  factory FlyerDetail.fromJson(Map<String, dynamic> json) =>
      _$FlyerDetailFromJson(json);

  Map<String, dynamic> toJson() => _$FlyerDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
