// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logout_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogoutRequest _$LogoutRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LogoutRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['refresh'],
        );
        final val = LogoutRequest(
          refresh: $checkedConvert('refresh', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$LogoutRequestToJson(LogoutRequest instance) =>
    <String, dynamic>{
      'refresh': instance.refresh,
    };
