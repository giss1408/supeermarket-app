// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_staff_category_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedStaffCategoryRequest _$PatchedStaffCategoryRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedStaffCategoryRequest',
      json,
      ($checkedConvert) {
        final val = PatchedStaffCategoryRequest(
          name: $checkedConvert('name', (v) => v as String?),
          slug: $checkedConvert('slug', (v) => v as String?),
          sortOrder: $checkedConvert('sort_order', (v) => (v as num?)?.toInt()),
        );
        return val;
      },
      fieldKeyMap: const {'sortOrder': 'sort_order'},
    );

Map<String, dynamic> _$PatchedStaffCategoryRequestToJson(
        PatchedStaffCategoryRequest instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.slug case final value?) 'slug': value,
      if (instance.sortOrder case final value?) 'sort_order': value,
    };
