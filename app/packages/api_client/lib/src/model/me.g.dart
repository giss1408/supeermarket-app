// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Me _$MeFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Me',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'email', 'role'],
        );
        final val = Me(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          email: $checkedConvert('email', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String?),
          role:
              $checkedConvert('role', (v) => $enumDecode(_$RoleEnumEnumMap, v)),
        );
        return val;
      },
    );

Map<String, dynamic> _$MeToJson(Me instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      if (instance.name case final value?) 'name': value,
      'role': _$RoleEnumEnumMap[instance.role]!,
    };

const _$RoleEnumEnumMap = {
  RoleEnum.customer: 'customer',
  RoleEnum.staff: 'staff',
};
