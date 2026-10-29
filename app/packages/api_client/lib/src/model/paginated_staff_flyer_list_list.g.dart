// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_staff_flyer_list_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedStaffFlyerListList _$PaginatedStaffFlyerListListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedStaffFlyerListList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedStaffFlyerListList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map(
                      (e) => StaffFlyerList.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedStaffFlyerListListToJson(
        PaginatedStaffFlyerListList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
