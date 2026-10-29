//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/opening_hours.dart';
import 'package:json_annotation/json_annotation.dart';

part 'store_detail.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StoreDetail {
  /// Returns a new [StoreDetail] instance.
  StoreDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    this.phone,
    required this.distanceKm,
    required this.openingHours,
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
    name: r'address',
    required: true,
    includeIfNull: false,
  )
  final String address;

  @JsonKey(
    name: r'city',
    required: true,
    includeIfNull: false,
  )
  final String city;

  @JsonKey(
    name: r'postcode',
    required: true,
    includeIfNull: false,
  )
  final String postcode;

  @JsonKey(
    name: r'latitude',
    required: true,
    includeIfNull: false,
  )
  final String latitude;

  @JsonKey(
    name: r'longitude',
    required: true,
    includeIfNull: false,
  )
  final String longitude;

  @JsonKey(
    name: r'phone',
    required: false,
    includeIfNull: false,
  )
  final String? phone;

  @JsonKey(
    name: r'distance_km',
    required: true,
    includeIfNull: true,
  )
  final double? distanceKm;

  @JsonKey(
    name: r'opening_hours',
    required: true,
    includeIfNull: false,
  )
  final List<OpeningHours> openingHours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreDetail &&
          other.id == id &&
          other.name == name &&
          other.address == address &&
          other.city == city &&
          other.postcode == postcode &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.phone == phone &&
          other.distanceKm == distanceKm &&
          other.openingHours == openingHours;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      address.hashCode +
      city.hashCode +
      postcode.hashCode +
      latitude.hashCode +
      longitude.hashCode +
      phone.hashCode +
      (distanceKm == null ? 0 : distanceKm.hashCode) +
      openingHours.hashCode;

  factory StoreDetail.fromJson(Map<String, dynamic> json) =>
      _$StoreDetailFromJson(json);

  Map<String, dynamic> toJson() => _$StoreDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
