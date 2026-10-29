//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/role_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'register.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Register {
  /// Returns a new [Register] instance.
  Register({
    required this.id,
    required this.email,
    this.name,
    required this.role,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'email',
    required: true,
    includeIfNull: false,
  )
  final String email;

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    name: r'role',
    required: true,
    includeIfNull: false,
  )
  final RoleEnum role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Register &&
          other.id == id &&
          other.email == email &&
          other.name == name &&
          other.role == role;

  @override
  int get hashCode =>
      id.hashCode + email.hashCode + name.hashCode + role.hashCode;

  factory Register.fromJson(Map<String, dynamic> json) =>
      _$RegisterFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
