// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_product_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffProductRequest _$StaffProductRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffProductRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['name', 'category'],
        );
        final val = StaffProductRequest(
          name: $checkedConvert('name', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String?),
          category: $checkedConvert('category', (v) => (v as num).toInt()),
          unit: $checkedConvert('unit', (v) => v as String?),
          ean: $checkedConvert('ean', (v) => v as String?),
          imageName: $checkedConvert('image_name', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'imageName': 'image_name'},
    );

Map<String, dynamic> _$StaffProductRequestToJson(
        StaffProductRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      if (instance.description case final value?) 'description': value,
      'category': instance.category,
      if (instance.unit case final value?) 'unit': value,
      if (instance.ean case final value?) 'ean': value,
      if (instance.imageName case final value?) 'image_name': value,
    };
