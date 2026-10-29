//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'token_refresh.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TokenRefresh {
  /// Returns a new [TokenRefresh] instance.
  TokenRefresh({
    required this.access,
    required this.refresh,
  });

  @JsonKey(
    name: r'access',
    required: true,
    includeIfNull: false,
  )
  final String access;

  @JsonKey(
    name: r'refresh',
    required: true,
    includeIfNull: false,
  )
  final String refresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenRefresh &&
          other.access == access &&
          other.refresh == refresh;

  @override
  int get hashCode => access.hashCode + refresh.hashCode;

  factory TokenRefresh.fromJson(Map<String, dynamic> json) =>
      _$TokenRefreshFromJson(json);

  Map<String, dynamic> toJson() => _$TokenRefreshToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
