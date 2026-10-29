// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_flyer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffFlyer _$StaffFlyerFromJson(Map<String, dynamic> json) => $checkedCreate(
      'StaffFlyer',
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
            'cover_image'
          ],
        );
        final val = StaffFlyer(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          title: $checkedConvert('title', (v) => v as String),
          validFrom:
              $checkedConvert('valid_from', (v) => DateTime.parse(v as String)),
          validTo:
              $checkedConvert('valid_to', (v) => DateTime.parse(v as String)),
          status: $checkedConvert(
              'status', (v) => $enumDecode(_$StatusEnumEnumMap, v)),
          coverImage: $checkedConvert('cover_image', (v) => v as String?),
          offers: $checkedConvert(
              'offers',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => OfferFields.fromJson(e as Map<String, dynamic>))
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

Map<String, dynamic> _$StaffFlyerToJson(StaffFlyer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_to': instance.validTo.toIso8601String(),
      'status': _$StatusEnumEnumMap[instance.status]!,
      'cover_image': instance.coverImage,
      if (instance.offers?.map((e) => e.toJson()).toList() case final value?)
        'offers': value,
    };

const _$StatusEnumEnumMap = {
  StatusEnum.draft: 'draft',
  StatusEnum.published: 'published',
};
