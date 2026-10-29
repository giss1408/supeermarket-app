// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_staff_payment_method_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedStaffPaymentMethodRequest _$PatchedStaffPaymentMethodRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedStaffPaymentMethodRequest',
      json,
      ($checkedConvert) {
        final val = PatchedStaffPaymentMethodRequest(
          provider: $checkedConvert(
              'provider', (v) => $enumDecodeNullable(_$ProviderEnumEnumMap, v)),
          phoneNumber: $checkedConvert('phone_number', (v) => v as String?),
          displayName: $checkedConvert('display_name', (v) => v as String?),
          instructions: $checkedConvert('instructions', (v) => v as String?),
          isActive: $checkedConvert('is_active', (v) => v as bool?),
          currentPassword:
              $checkedConvert('current_password', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'phoneNumber': 'phone_number',
        'displayName': 'display_name',
        'isActive': 'is_active',
        'currentPassword': 'current_password'
      },
    );

Map<String, dynamic> _$PatchedStaffPaymentMethodRequestToJson(
        PatchedStaffPaymentMethodRequest instance) =>
    <String, dynamic>{
      if (_$ProviderEnumEnumMap[instance.provider] case final value?)
        'provider': value,
      if (instance.phoneNumber case final value?) 'phone_number': value,
      if (instance.displayName case final value?) 'display_name': value,
      if (instance.instructions case final value?) 'instructions': value,
      if (instance.isActive case final value?) 'is_active': value,
      if (instance.currentPassword case final value?) 'current_password': value,
    };

const _$ProviderEnumEnumMap = {
  ProviderEnum.wave: 'wave',
  ProviderEnum.orangeMoney: 'orange_money',
  ProviderEnum.mtnMomo: 'mtn_momo',
};
