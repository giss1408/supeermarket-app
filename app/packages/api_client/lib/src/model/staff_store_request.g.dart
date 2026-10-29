// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_store_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffStoreRequest _$StaffStoreRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffStoreRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'name',
            'address',
            'city',
            'postcode',
            'latitude',
            'longitude'
          ],
        );
        final val = StaffStoreRequest(
          name: $checkedConvert('name', (v) => v as String),
          address: $checkedConvert('address', (v) => v as String),
          city: $checkedConvert('city', (v) => v as String),
          postcode: $checkedConvert('postcode', (v) => v as String),
          latitude: $checkedConvert('latitude', (v) => v as String),
          longitude: $checkedConvert('longitude', (v) => v as String),
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

Map<String, dynamic> _$StaffStoreRequestToJson(StaffStoreRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
      'city': instance.city,
      'postcode': instance.postcode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      if (instance.phone case final value?) 'phone': value,
      if (instance.isActive case final value?) 'is_active': value,
      if (instance.openingHours?.map((e) => e.toJson()).toList()
          case final value?)
        'opening_hours': value,
    };
