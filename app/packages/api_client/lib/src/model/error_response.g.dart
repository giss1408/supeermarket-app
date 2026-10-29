// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ErrorResponse',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['code', 'detail', 'fields'],
        );
        final val = ErrorResponse(
          code: $checkedConvert('code', (v) => v as String),
          detail: $checkedConvert('detail', (v) => v as String),
          fields: $checkedConvert(
              'fields',
              (v) => (v as Map<String, dynamic>).map(
                    (k, e) => MapEntry(k,
                        (e as List<dynamic>).map((e) => e as String).toList()),
                  )),
        );
        return val;
      },
    );

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'detail': instance.detail,
      'fields': instance.fields,
    };
