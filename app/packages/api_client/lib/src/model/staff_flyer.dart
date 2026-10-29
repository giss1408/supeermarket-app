//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/status_enum.dart';
import 'package:api_client/src/model/offer_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'staff_flyer.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffFlyer {
  /// Returns a new [StaffFlyer] instance.
  StaffFlyer({
    required this.id,
    required this.title,
    required this.validFrom,
    required this.validTo,
    required this.status,
    required this.coverImage,
    this.offers,
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
    name: r'status',
    required: true,
    includeIfNull: false,
  )
  final StatusEnum status;

  @JsonKey(
    name: r'cover_image',
    required: true,
    includeIfNull: true,
  )
  final String? coverImage;

  @JsonKey(
    name: r'offers',
    required: false,
    includeIfNull: false,
  )
  final List<OfferFields>? offers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffFlyer &&
          other.id == id &&
          other.title == title &&
          other.validFrom == validFrom &&
          other.validTo == validTo &&
          other.status == status &&
          other.coverImage == coverImage &&
          other.offers == offers;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      validFrom.hashCode +
      validTo.hashCode +
      status.hashCode +
      (coverImage == null ? 0 : coverImage.hashCode) +
      offers.hashCode;

  factory StaffFlyer.fromJson(Map<String, dynamic> json) =>
      _$StaffFlyerFromJson(json);

  Map<String, dynamic> toJson() => _$StaffFlyerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
