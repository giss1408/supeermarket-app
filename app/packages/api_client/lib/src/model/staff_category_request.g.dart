// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_category_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffCategoryRequest _$StaffCategoryRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffCategoryRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['name', 'slug'],
        );
        final val = StaffCategoryRequest(
          name: $checkedConvert('name', (v) => v as String),
          slug: $checkedConvert('slug', (v) => v as String),
          sortOrder: $checkedConvert('sort_order', (v) => (v as num?)?.toInt()),
        );
        return val;
      },
      fieldKeyMap: const {'sortOrder': 'sort_order'},
    );

Map<String, dynamic> _$StaffCategoryRequestToJson(
        StaffCategoryRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slug': instance.slug,
      if (instance.sortOrder case final value?) 'sort_order': value,
    };
