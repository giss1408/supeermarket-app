// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flyer_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlyerList _$FlyerListFromJson(Map<String, dynamic> json) => $checkedCreate(
      'FlyerList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'title',
            'valid_from',
            'valid_to',
            'offer_count'
          ],
        );
        final val = FlyerList(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          title: $checkedConvert('title', (v) => v as String),
          validFrom:
              $checkedConvert('valid_from', (v) => DateTime.parse(v as String)),
          validTo:
              $checkedConvert('valid_to', (v) => DateTime.parse(v as String)),
          coverImage: $checkedConvert('cover_image', (v) => v as String?),
          offerCount: $checkedConvert('offer_count', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'validFrom': 'valid_from',
        'validTo': 'valid_to',
        'coverImage': 'cover_image',
        'offerCount': 'offer_count'
      },
    );

Map<String, dynamic> _$FlyerListToJson(FlyerList instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_to': instance.validTo.toIso8601String(),
      if (instance.coverImage case final value?) 'cover_image': value,
      'offer_count': instance.offerCount,
    };
