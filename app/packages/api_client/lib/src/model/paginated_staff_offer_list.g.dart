// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_staff_offer_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedStaffOfferList _$PaginatedStaffOfferListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedStaffOfferList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedStaffOfferList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => StaffOffer.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedStaffOfferListToJson(
        PaginatedStaffOfferList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
