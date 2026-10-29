// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Store _$StoreFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Store',
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
            'distance_km'
          ],
        );
        final val = Store(
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
        );
        return val;
      },
      fieldKeyMap: const {'distanceKm': 'distance_km'},
    );

Map<String, dynamic> _$StoreToJson(Store instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'city': instance.city,
      'postcode': instance.postcode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      if (instance.phone case final value?) 'phone': value,
      'distance_km': instance.distanceKm,
    };
