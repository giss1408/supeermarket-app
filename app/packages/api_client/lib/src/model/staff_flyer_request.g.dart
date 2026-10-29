// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_flyer_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffFlyerRequest _$StaffFlyerRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffFlyerRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['title', 'valid_from', 'valid_to'],
        );
        final val = StaffFlyerRequest(
          title: $checkedConvert('title', (v) => v as String),
          validFrom:
              $checkedConvert('valid_from', (v) => DateTime.parse(v as String)),
          validTo:
              $checkedConvert('valid_to', (v) => DateTime.parse(v as String)),
          coverImageName:
              $checkedConvert('cover_image_name', (v) => v as String?),
          offers: $checkedConvert(
              'offers',
              (v) => (v as List<dynamic>?)
                  ?.map((e) =>
                      OfferFieldsRequest.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
      fieldKeyMap: const {
        'validFrom': 'valid_from',
        'validTo': 'valid_to',
        'coverImageName': 'cover_image_name'
      },
    );

Map<String, dynamic> _$StaffFlyerRequestToJson(StaffFlyerRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_to': instance.validTo.toIso8601String(),
      if (instance.coverImageName case final value?) 'cover_image_name': value,
      if (instance.offers?.map((e) => e.toJson()).toList() case final value?)
        'offers': value,
    };
