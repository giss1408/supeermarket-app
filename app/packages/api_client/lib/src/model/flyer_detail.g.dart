// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flyer_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlyerDetail _$FlyerDetailFromJson(Map<String, dynamic> json) => $checkedCreate(
      'FlyerDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'title',
            'valid_from',
            'valid_to',
            'offers'
          ],
        );
        final val = FlyerDetail(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          title: $checkedConvert('title', (v) => v as String),
          validFrom:
              $checkedConvert('valid_from', (v) => DateTime.parse(v as String)),
          validTo:
              $checkedConvert('valid_to', (v) => DateTime.parse(v as String)),
          coverImage: $checkedConvert('cover_image', (v) => v as String?),
          offers: $checkedConvert(
              'offers',
              (v) => (v as List<dynamic>)
                  .map((e) => Offer.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
      fieldKeyMap: const {
        'validFrom': 'valid_from',
        'validTo': 'valid_to',
        'coverImage': 'cover_image'
      },
    );

Map<String, dynamic> _$FlyerDetailToJson(FlyerDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_to': instance.validTo.toIso8601String(),
      if (instance.coverImage case final value?) 'cover_image': value,
      'offers': instance.offers.map((e) => e.toJson()).toList(),
    };
