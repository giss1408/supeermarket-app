// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_obtain_pair.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenObtainPair _$TokenObtainPairFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TokenObtainPair',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['access', 'refresh'],
        );
        final val = TokenObtainPair(
          access: $checkedConvert('access', (v) => v as String),
          refresh: $checkedConvert('refresh', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$TokenObtainPairToJson(TokenObtainPair instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
    };
