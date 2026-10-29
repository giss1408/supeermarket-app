//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/offer_fields_request.dart';
import 'package:json_annotation/json_annotation.dart';

part 'staff_flyer_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffFlyerRequest {
  /// Returns a new [StaffFlyerRequest] instance.
  StaffFlyerRequest({
    required this.title,
    required this.validFrom,
    required this.validTo,
    this.coverImageName,
    this.offers,
  });

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
    name: r'cover_image_name',
    required: false,
    includeIfNull: false,
  )
  final String? coverImageName;

  @JsonKey(
    name: r'offers',
    required: false,
    includeIfNull: false,
  )
  final List<OfferFieldsRequest>? offers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffFlyerRequest &&
          other.title == title &&
          other.validFrom == validFrom &&
          other.validTo == validTo &&
          other.coverImageName == coverImageName &&
          other.offers == offers;

  @override
  int get hashCode =>
      title.hashCode +
      validFrom.hashCode +
      validTo.hashCode +
      (coverImageName == null ? 0 : coverImageName.hashCode) +
      offers.hashCode;

  factory StaffFlyerRequest.fromJson(Map<String, dynamic> json) =>
      _$StaffFlyerRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StaffFlyerRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
