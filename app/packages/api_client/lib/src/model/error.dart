//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'error.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Error {
  /// Returns a new [Error] instance.
  Error({
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
      other is Error &&
          other.code == code &&
          other.detail == detail &&
          other.fields == fields;

  @override
  int get hashCode => code.hashCode + detail.hashCode + fields.hashCode;

  factory Error.fromJson(Map<String, dynamic> json) => _$ErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
