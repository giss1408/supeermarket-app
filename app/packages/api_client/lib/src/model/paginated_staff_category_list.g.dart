// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_staff_category_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedStaffCategoryList _$PaginatedStaffCategoryListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedStaffCategoryList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedStaffCategoryList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => StaffCategory.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedStaffCategoryListToJson(
        PaginatedStaffCategoryList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
