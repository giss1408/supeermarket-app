// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Register _$RegisterFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Register',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'email', 'role'],
        );
        final val = Register(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          email: $checkedConvert('email', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String?),
          role:
              $checkedConvert('role', (v) => $enumDecode(_$RoleEnumEnumMap, v)),
        );
        return val;
      },
    );

Map<String, dynamic> _$RegisterToJson(Register instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      if (instance.name case final value?) 'name': value,
      'role': _$RoleEnumEnumMap[instance.role]!,
    };

const _$RoleEnumEnumMap = {
  RoleEnum.customer: 'customer',
  RoleEnum.staff: 'staff',
};
