// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_refresh.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenRefresh _$TokenRefreshFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TokenRefresh',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['access', 'refresh'],
        );
        final val = TokenRefresh(
          access: $checkedConvert('access', (v) => v as String),
          refresh: $checkedConvert('refresh', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$TokenRefreshToJson(TokenRefresh instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
    };
