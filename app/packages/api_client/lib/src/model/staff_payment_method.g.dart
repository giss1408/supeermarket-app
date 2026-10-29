// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_payment_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffPaymentMethod _$StaffPaymentMethodFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffPaymentMethod',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'provider', 'phone_number', 'updated_at'],
        );
        final val = StaffPaymentMethod(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          provider: $checkedConvert(
              'provider', (v) => $enumDecode(_$ProviderEnumEnumMap, v)),
          phoneNumber: $checkedConvert('phone_number', (v) => v as String),
          displayName: $checkedConvert('display_name', (v) => v as String?),
          instructions: $checkedConvert('instructions', (v) => v as String?),
          isActive: $checkedConvert('is_active', (v) => v as bool?),
          updatedAt:
              $checkedConvert('updated_at', (v) => DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {
        'phoneNumber': 'phone_number',
        'displayName': 'display_name',
        'isActive': 'is_active',
        'updatedAt': 'updated_at'
      },
    );

Map<String, dynamic> _$StaffPaymentMethodToJson(StaffPaymentMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'provider': _$ProviderEnumEnumMap[instance.provider]!,
      'phone_number': instance.phoneNumber,
      if (instance.displayName case final value?) 'display_name': value,
      if (instance.instructions case final value?) 'instructions': value,
      if (instance.isActive case final value?) 'is_active': value,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$ProviderEnumEnumMap = {
  ProviderEnum.wave: 'wave',
  ProviderEnum.orangeMoney: 'orange_money',
  ProviderEnum.mtnMomo: 'mtn_momo',
};
