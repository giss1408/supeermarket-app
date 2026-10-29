// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffCategory _$StaffCategoryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffCategory',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'name', 'slug'],
        );
        final val = StaffCategory(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          slug: $checkedConvert('slug', (v) => v as String),
          sortOrder: $checkedConvert('sort_order', (v) => (v as num?)?.toInt()),
        );
        return val;
      },
      fieldKeyMap: const {'sortOrder': 'sort_order'},
    );

Map<String, dynamic> _$StaffCategoryToJson(StaffCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      if (instance.sortOrder case final value?) 'sort_order': value,
    };
