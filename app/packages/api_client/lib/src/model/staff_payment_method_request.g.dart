// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_payment_method_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffPaymentMethodRequest _$StaffPaymentMethodRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffPaymentMethodRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['provider', 'phone_number', 'current_password'],
        );
        final val = StaffPaymentMethodRequest(
          provider: $checkedConvert(
              'provider', (v) => $enumDecode(_$ProviderEnumEnumMap, v)),
          phoneNumber: $checkedConvert('phone_number', (v) => v as String),
          displayName: $checkedConvert('display_name', (v) => v as String?),
          instructions: $checkedConvert('instructions', (v) => v as String?),
          isActive: $checkedConvert('is_active', (v) => v as bool?),
          currentPassword:
              $checkedConvert('current_password', (v) => v as String),
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

Map<String, dynamic> _$StaffPaymentMethodRequestToJson(
        StaffPaymentMethodRequest instance) =>
    <String, dynamic>{
      'provider': _$ProviderEnumEnumMap[instance.provider]!,
      'phone_number': instance.phoneNumber,
      if (instance.displayName case final value?) 'display_name': value,
      if (instance.instructions case final value?) 'instructions': value,
      if (instance.isActive case final value?) 'is_active': value,
      'current_password': instance.currentPassword,
    };

const _$ProviderEnumEnumMap = {
  ProviderEnum.wave: 'wave',
  ProviderEnum.orangeMoney: 'orange_money',
  ProviderEnum.mtnMomo: 'mtn_momo',
};
