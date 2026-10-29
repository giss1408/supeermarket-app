//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'logout_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LogoutRequest {
  /// Returns a new [LogoutRequest] instance.
  LogoutRequest({
    required this.refresh,
  });

  @JsonKey(
    name: r'refresh',
    required: true,
    includeIfNull: false,
  )
  final String refresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoutRequest && other.refresh == refresh;

  @override
  int get hashCode => refresh.hashCode;

  factory LogoutRequest.fromJson(Map<String, dynamic> json) =>
      _$LogoutRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LogoutRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
