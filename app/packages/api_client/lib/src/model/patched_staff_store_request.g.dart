// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_staff_store_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedStaffStoreRequest _$PatchedStaffStoreRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedStaffStoreRequest',
      json,
      ($checkedConvert) {
        final val = PatchedStaffStoreRequest(
          name: $checkedConvert('name', (v) => v as String?),
          address: $checkedConvert('address', (v) => v as String?),
          city: $checkedConvert('city', (v) => v as String?),
          postcode: $checkedConvert('postcode', (v) => v as String?),
          latitude: $checkedConvert('latitude', (v) => v as String?),
          longitude: $checkedConvert('longitude', (v) => v as String?),
          phone: $checkedConvert('phone', (v) => v as String?),
          isActive: $checkedConvert('is_active', (v) => v as bool?),
          openingHours: $checkedConvert(
              'opening_hours',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => OpeningHoursWriteRequest.fromJson(
                      e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
      fieldKeyMap: const {
        'isActive': 'is_active',
        'openingHours': 'opening_hours'
      },
    );

Map<String, dynamic> _$PatchedStaffStoreRequestToJson(
        PatchedStaffStoreRequest instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.address case final value?) 'address': value,
      if (instance.city case final value?) 'city': value,
      if (instance.postcode case final value?) 'postcode': value,
      if (instance.latitude case final value?) 'latitude': value,
      if (instance.longitude case final value?) 'longitude': value,
      if (instance.phone case final value?) 'phone': value,
      if (instance.isActive case final value?) 'is_active': value,
      if (instance.openingHours?.map((e) => e.toJson()).toList()
          case final value?)
        'opening_hours': value,
    };
