//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'opening_hours.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OpeningHours {
  /// Returns a new [OpeningHours] instance.
  OpeningHours({
    required this.weekday,
    required this.opens,
    required this.closes,
  });

  // minimum: 0
  // maximum: 6
  @JsonKey(
    name: r'weekday',
    required: true,
    includeIfNull: false,
  )
  final int weekday;

  @JsonKey(
    name: r'opens',
    required: true,
    includeIfNull: false,
  )
  final String opens;

  @JsonKey(
    name: r'closes',
    required: true,
    includeIfNull: false,
  )
  final String closes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpeningHours &&
          other.weekday == weekday &&
          other.opens == opens &&
          other.closes == closes;

  @override
  int get hashCode => weekday.hashCode + opens.hashCode + closes.hashCode;

  factory OpeningHours.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
