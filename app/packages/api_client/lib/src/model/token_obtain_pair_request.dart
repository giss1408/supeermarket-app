//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'token_obtain_pair_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TokenObtainPairRequest {
  /// Returns a new [TokenObtainPairRequest] instance.
  TokenObtainPairRequest({
    required this.email,
    required this.password,
  });

  @JsonKey(
    name: r'email',
    required: true,
    includeIfNull: false,
  )
  final String email;

  @JsonKey(
    name: r'password',
    required: true,
    includeIfNull: false,
  )
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenObtainPairRequest &&
          other.email == email &&
          other.password == password;

  @override
  int get hashCode => email.hashCode + password.hashCode;

  factory TokenObtainPairRequest.fromJson(Map<String, dynamic> json) =>
      _$TokenObtainPairRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TokenObtainPairRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
