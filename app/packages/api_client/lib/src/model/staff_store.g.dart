// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffStore _$StaffStoreFromJson(Map<String, dynamic> json) => $checkedCreate(
      'StaffStore',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'name',
            'address',
            'city',
            'postcode',
            'latitude',
            'longitude'
          ],
        );
        final val = StaffStore(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
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
                  ?.map((e) =>
                      OpeningHoursWrite.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
      fieldKeyMap: const {
        'isActive': 'is_active',
        'openingHours': 'opening_hours'
      },
    );

Map<String, dynamic> _$StaffStoreToJson(StaffStore instance) =>
    <String, dynamic>{
      'id': instance.id,
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
