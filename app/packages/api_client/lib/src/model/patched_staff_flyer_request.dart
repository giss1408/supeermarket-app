//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/offer_fields_request.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_staff_flyer_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedStaffFlyerRequest {
  /// Returns a new [PatchedStaffFlyerRequest] instance.
  PatchedStaffFlyerRequest({
    this.title,
    this.validFrom,
    this.validTo,
    this.coverImageName,
    this.offers,
  });

  @JsonKey(
    name: r'title',
    required: false,
    includeIfNull: false,
  )
  final String? title;

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
      other is PatchedStaffFlyerRequest &&
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

  factory PatchedStaffFlyerRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedStaffFlyerRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedStaffFlyerRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
