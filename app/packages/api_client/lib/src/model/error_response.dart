//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'error_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorResponse {
  /// Returns a new [ErrorResponse] instance.
  ErrorResponse({
    required this.code,
    required this.detail,
    required this.fields,
  });

  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
  )
  final String code;

  @JsonKey(
    name: r'detail',
    required: true,
    includeIfNull: false,
  )
  final String detail;

  @JsonKey(
    name: r'fields',
    required: true,
    includeIfNull: false,
  )
  final Map<String, List<String>> fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorResponse &&
          other.code == code &&
          other.detail == detail &&
          other.fields == fields;

  @override
  int get hashCode => code.hashCode + detail.hashCode + fields.hashCode;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
