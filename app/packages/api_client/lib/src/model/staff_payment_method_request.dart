//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'staff_payment_method_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StaffPaymentMethodRequest {
  /// Returns a new [StaffPaymentMethodRequest] instance.
  StaffPaymentMethodRequest({
    required this.provider,
    required this.phoneNumber,
    this.displayName,
    this.instructions,
    this.isActive,
    required this.currentPassword,
  });

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
    name: r'current_password',
    required: true,
    includeIfNull: false,
  )
  final String currentPassword;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentMethodRequest &&
          other.provider == provider &&
          other.phoneNumber == phoneNumber &&
          other.displayName == displayName &&
          other.instructions == instructions &&
          other.isActive == isActive &&
          other.currentPassword == currentPassword;

  @override
  int get hashCode =>
      provider.hashCode +
      phoneNumber.hashCode +
      displayName.hashCode +
      instructions.hashCode +
      isActive.hashCode +
      currentPassword.hashCode;

  factory StaffPaymentMethodRequest.fromJson(Map<String, dynamic> json) =>
      _$StaffPaymentMethodRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StaffPaymentMethodRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
