//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'token_obtain_pair.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TokenObtainPair {
  /// Returns a new [TokenObtainPair] instance.
  TokenObtainPair({
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
      other is TokenObtainPair &&
          other.access == access &&
          other.refresh == refresh;

  @override
  int get hashCode => access.hashCode + refresh.hashCode;

  factory TokenObtainPair.fromJson(Map<String, dynamic> json) =>
      _$TokenObtainPairFromJson(json);

  Map<String, dynamic> toJson() => _$TokenObtainPairToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
