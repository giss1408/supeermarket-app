// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_staff_flyer_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedStaffFlyerRequest _$PatchedStaffFlyerRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedStaffFlyerRequest',
      json,
      ($checkedConvert) {
        final val = PatchedStaffFlyerRequest(
          title: $checkedConvert('title', (v) => v as String?),
          validFrom: $checkedConvert('valid_from',
              (v) => v == null ? null : DateTime.parse(v as String)),
          validTo: $checkedConvert('valid_to',
              (v) => v == null ? null : DateTime.parse(v as String)),
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

Map<String, dynamic> _$PatchedStaffFlyerRequestToJson(
        PatchedStaffFlyerRequest instance) =>
    <String, dynamic>{
      if (instance.title case final value?) 'title': value,
      if (instance.validFrom?.toIso8601String() case final value?)
        'valid_from': value,
      if (instance.validTo?.toIso8601String() case final value?)
        'valid_to': value,
      if (instance.coverImageName case final value?) 'cover_image_name': value,
      if (instance.offers?.map((e) => e.toJson()).toList() case final value?)
        'offers': value,
    };
