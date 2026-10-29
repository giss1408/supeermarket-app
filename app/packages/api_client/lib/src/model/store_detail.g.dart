// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoreDetail _$StoreDetailFromJson(Map<String, dynamic> json) => $checkedCreate(
      'StoreDetail',
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
            'longitude',
            'distance_km',
            'opening_hours'
          ],
        );
        final val = StoreDetail(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          address: $checkedConvert('address', (v) => v as String),
          city: $checkedConvert('city', (v) => v as String),
          postcode: $checkedConvert('postcode', (v) => v as String),
          latitude: $checkedConvert('latitude', (v) => v as String),
          longitude: $checkedConvert('longitude', (v) => v as String),
          phone: $checkedConvert('phone', (v) => v as String?),
          distanceKm:
              $checkedConvert('distance_km', (v) => (v as num?)?.toDouble()),
          openingHours: $checkedConvert(
              'opening_hours',
              (v) => (v as List<dynamic>)
                  .map((e) => OpeningHours.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
      fieldKeyMap: const {
        'distanceKm': 'distance_km',
        'openingHours': 'opening_hours'
      },
    );

Map<String, dynamic> _$StoreDetailToJson(StoreDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'city': instance.city,
      'postcode': instance.postcode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      if (instance.phone case final value?) 'phone': value,
      'distance_km': instance.distanceKm,
      'opening_hours': instance.openingHours.map((e) => e.toJson()).toList(),
    };
