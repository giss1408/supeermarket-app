//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'staff_payment_method.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffPaymentMethod {
  /// Returns a new [StaffPaymentMethod] instance.
  StaffPaymentMethod({
    required this.id,
    required this.provider,
    required this.phoneNumber,
    this.displayName,
    this.instructions,
    this.isActive,
    required this.updatedAt,
  });

  @JsonKey(
    name: r'id',
    required: true,
    includeIfNull: false,
  )
  final int id;

  @JsonKey(
    name: r'provider',
    required: true,
    includeIfNull: false,
  )
  final ProviderEnum provider;

  @JsonKey(
    name: r'phone_number',
    required: true,
    includeIfNull: false,
  )
  final String phoneNumber;

  @JsonKey(
    name: r'display_name',
    required: false,
    includeIfNull: false,
  )
  final String? displayName;

  @JsonKey(
    name: r'instructions',
    required: false,
    includeIfNull: false,
  )
  final String? instructions;

  @JsonKey(
    name: r'is_active',
    required: false,
    includeIfNull: false,
  )
  final bool? isActive;

  @JsonKey(
    name: r'updated_at',
    required: true,
    includeIfNull: false,
  )
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentMethod &&
          other.id == id &&
          other.provider == provider &&
          other.phoneNumber == phoneNumber &&
          other.displayName == displayName &&
          other.instructions == instructions &&
          other.isActive == isActive &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      provider.hashCode +
      phoneNumber.hashCode +
      displayName.hashCode +
      instructions.hashCode +
      isActive.hashCode +
      updatedAt.hashCode;

  factory StaffPaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$StaffPaymentMethodFromJson(json);

  Map<String, dynamic> toJson() => _$StaffPaymentMethodToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
