//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/opening_hours_write_request.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_staff_store_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedStaffStoreRequest {
  /// Returns a new [PatchedStaffStoreRequest] instance.
  PatchedStaffStoreRequest({
    this.name,
    this.address,
    this.city,
    this.postcode,
    this.latitude,
    this.longitude,
    this.phone,
    this.isActive,
    this.openingHours,
  });

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    name: r'address',
    required: false,
    includeIfNull: false,
  )
  final String? address;

  @JsonKey(
    name: r'city',
    required: false,
    includeIfNull: false,
  )
  final String? city;

  @JsonKey(
    name: r'postcode',
    required: false,
    includeIfNull: false,
  )
  final String? postcode;

  @JsonKey(
    name: r'latitude',
    required: false,
    includeIfNull: false,
  )
  final String? latitude;

  @JsonKey(
    name: r'longitude',
    required: false,
    includeIfNull: false,
  )
  final String? longitude;

  @JsonKey(
    name: r'phone',
    required: false,
    includeIfNull: false,
  )
  final String? phone;

  @JsonKey(
    name: r'is_active',
    required: false,
    includeIfNull: false,
  )
  final bool? isActive;

  @JsonKey(
    name: r'opening_hours',
    required: false,
    includeIfNull: false,
  )
  final List<OpeningHoursWriteRequest>? openingHours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedStaffStoreRequest &&
          other.name == name &&
          other.address == address &&
          other.city == city &&
          other.postcode == postcode &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.phone == phone &&
          other.isActive == isActive &&
          other.openingHours == openingHours;

  @override
  int get hashCode =>
      name.hashCode +
      address.hashCode +
      city.hashCode +
      postcode.hashCode +
      latitude.hashCode +
      longitude.hashCode +
      phone.hashCode +
      isActive.hashCode +
      openingHours.hashCode;

  factory PatchedStaffStoreRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedStaffStoreRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedStaffStoreRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
