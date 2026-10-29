//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'store.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Store {
  /// Returns a new [Store] instance.
  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    this.phone,
    required this.distanceKm,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store &&
          other.id == id &&
          other.name == name &&
          other.address == address &&
          other.city == city &&
          other.postcode == postcode &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.phone == phone &&
          other.distanceKm == distanceKm;

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
      (distanceKm == null ? 0 : distanceKm.hashCode);

  factory Store.fromJson(Map<String, dynamic> json) => _$StoreFromJson(json);

  Map<String, dynamic> toJson() => _$StoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
