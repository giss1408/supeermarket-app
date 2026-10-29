// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PaymentMethod',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['provider', 'phone_number', 'updated_at'],
        );
        final val = PaymentMethod(
          provider: $checkedConvert(
              'provider', (v) => $enumDecode(_$ProviderEnumEnumMap, v)),
          phoneNumber: $checkedConvert('phone_number', (v) => v as String),
          displayName: $checkedConvert('display_name', (v) => v as String?),
          instructions: $checkedConvert('instructions', (v) => v as String?),
          updatedAt:
              $checkedConvert('updated_at', (v) => DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {
        'phoneNumber': 'phone_number',
        'displayName': 'display_name',
        'updatedAt': 'updated_at'
      },
    );

Map<String, dynamic> _$PaymentMethodToJson(PaymentMethod instance) =>
    <String, dynamic>{
      'provider': _$ProviderEnumEnumMap[instance.provider]!,
      'phone_number': instance.phoneNumber,
      if (instance.displayName case final value?) 'display_name': value,
      if (instance.instructions case final value?) 'instructions': value,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$ProviderEnumEnumMap = {
  ProviderEnum.wave: 'wave',
  ProviderEnum.orangeMoney: 'orange_money',
  ProviderEnum.mtnMomo: 'mtn_momo',
};
