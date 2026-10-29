// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_flyer_list_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedFlyerListList _$PaginatedFlyerListListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedFlyerListList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedFlyerListList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => FlyerList.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedFlyerListListToJson(
        PaginatedFlyerListList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
