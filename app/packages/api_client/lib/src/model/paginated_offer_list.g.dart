// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_offer_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedOfferList _$PaginatedOfferListFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedOfferList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedOfferList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => Offer.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedOfferListToJson(PaginatedOfferList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
