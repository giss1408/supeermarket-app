// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_upload_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageUploadResult _$ImageUploadResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ImageUploadResult',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['url', 'name'],
        );
        final val = ImageUploadResult(
          url: $checkedConvert('url', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$ImageUploadResultToJson(ImageUploadResult instance) =>
    <String, dynamic>{
      'url': instance.url,
      'name': instance.name,
    };
