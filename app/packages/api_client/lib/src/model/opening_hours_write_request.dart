//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'opening_hours_write_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OpeningHoursWriteRequest {
  /// Returns a new [OpeningHoursWriteRequest] instance.
  OpeningHoursWriteRequest({
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
      other is OpeningHoursWriteRequest &&
          other.weekday == weekday &&
          other.opens == opens &&
          other.closes == closes;

  @override
  int get hashCode => weekday.hashCode + opens.hashCode + closes.hashCode;

  factory OpeningHoursWriteRequest.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursWriteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursWriteRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
