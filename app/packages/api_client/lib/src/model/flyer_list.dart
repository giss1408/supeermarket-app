//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'flyer_list.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FlyerList {
  /// Returns a new [FlyerList] instance.
  FlyerList({
    required this.id,
    required this.title,
    required this.validFrom,
    required this.validTo,
    this.coverImage,
    required this.offerCount,
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
    name: r'offer_count',
    required: true,
    includeIfNull: false,
  )
  final int offerCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlyerList &&
          other.id == id &&
          other.title == title &&
          other.validFrom == validFrom &&
          other.validTo == validTo &&
          other.coverImage == coverImage &&
          other.offerCount == offerCount;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      validFrom.hashCode +
      validTo.hashCode +
      (coverImage == null ? 0 : coverImage.hashCode) +
      offerCount.hashCode;

  factory FlyerList.fromJson(Map<String, dynamic> json) =>
      _$FlyerListFromJson(json);

  Map<String, dynamic> toJson() => _$FlyerListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
