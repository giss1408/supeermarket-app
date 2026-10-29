//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_staff_payment_method_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedStaffPaymentMethodRequest {
  /// Returns a new [PatchedStaffPaymentMethodRequest] instance.
  PatchedStaffPaymentMethodRequest({
    this.provider,
    this.phoneNumber,
    this.displayName,
    this.instructions,
    this.isActive,
    this.currentPassword,
  });

  @JsonKey(
    name: r'provider',
    required: false,
    includeIfNull: false,
  )
  final ProviderEnum? provider;

  @JsonKey(
    name: r'phone_number',
    required: false,
    includeIfNull: false,
  )
  final String? phoneNumber;

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
    required: false,
    includeIfNull: false,
  )
  final String? currentPassword;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedStaffPaymentMethodRequest &&
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

  factory PatchedStaffPaymentMethodRequest.fromJson(
          Map<String, dynamic> json) =>
      _$PatchedStaffPaymentMethodRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchedStaffPaymentMethodRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
