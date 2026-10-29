// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_category_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedCategoryList _$PaginatedCategoryListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedCategoryList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedCategoryList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => Category.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedCategoryListToJson(
        PaginatedCategoryList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
