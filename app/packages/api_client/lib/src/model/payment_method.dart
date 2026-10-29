//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/provider_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_method.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaymentMethod {
  /// Returns a new [PaymentMethod] instance.
  PaymentMethod({
    required this.provider,
    required this.phoneNumber,
    this.displayName,
    this.instructions,
    required this.updatedAt,
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
    name: r'updated_at',
    required: true,
    includeIfNull: false,
  )
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethod &&
          other.provider == provider &&
          other.phoneNumber == phoneNumber &&
          other.displayName == displayName &&
          other.instructions == instructions &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      provider.hashCode +
      phoneNumber.hashCode +
      displayName.hashCode +
      instructions.hashCode +
      updatedAt.hashCode;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentMethodToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
