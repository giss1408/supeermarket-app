// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_flyer_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffFlyerList _$StaffFlyerListFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffFlyerList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'title',
            'valid_from',
            'valid_to',
            'status',
            'cover_image',
            'offer_count'
          ],
        );
        final val = StaffFlyerList(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          title: $checkedConvert('title', (v) => v as String),
          validFrom:
              $checkedConvert('valid_from', (v) => DateTime.parse(v as String)),
          validTo:
              $checkedConvert('valid_to', (v) => DateTime.parse(v as String)),
          status: $checkedConvert(
              'status', (v) => $enumDecode(_$StatusEnumEnumMap, v)),
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

Map<String, dynamic> _$StaffFlyerListToJson(StaffFlyerList instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_to': instance.validTo.toIso8601String(),
      'status': _$StatusEnumEnumMap[instance.status]!,
      'cover_image': instance.coverImage,
      'offer_count': instance.offerCount,
    };

const _$StatusEnumEnumMap = {
  StatusEnum.draft: 'draft',
  StatusEnum.published: 'published',
};
