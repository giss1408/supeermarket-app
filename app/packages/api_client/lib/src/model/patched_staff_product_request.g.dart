// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_staff_product_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedStaffProductRequest _$PatchedStaffProductRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedStaffProductRequest',
      json,
      ($checkedConvert) {
        final val = PatchedStaffProductRequest(
          name: $checkedConvert('name', (v) => v as String?),
          description: $checkedConvert('description', (v) => v as String?),
          category: $checkedConvert('category', (v) => (v as num?)?.toInt()),
          unit: $checkedConvert('unit', (v) => v as String?),
          ean: $checkedConvert('ean', (v) => v as String?),
          imageName: $checkedConvert('image_name', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'imageName': 'image_name'},
    );

Map<String, dynamic> _$PatchedStaffProductRequestToJson(
        PatchedStaffProductRequest instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.description case final value?) 'description': value,
      if (instance.category case final value?) 'category': value,
      if (instance.unit case final value?) 'unit': value,
      if (instance.ean case final value?) 'ean': value,
      if (instance.imageName case final value?) 'image_name': value,
    };
