// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_store_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedStoreList _$PaginatedStoreListFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedStoreList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedStoreList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => Store.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedStoreListToJson(PaginatedStoreList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
