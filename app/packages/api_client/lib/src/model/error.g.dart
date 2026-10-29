// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Error _$ErrorFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Error',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['code', 'detail', 'fields'],
        );
        final val = Error(
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

Map<String, dynamic> _$ErrorToJson(Error instance) => <String, dynamic>{
      'code': instance.code,
      'detail': instance.detail,
      'fields': instance.fields,
    };
