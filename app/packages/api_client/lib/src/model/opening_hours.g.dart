// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opening_hours.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpeningHours _$OpeningHoursFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OpeningHours',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['weekday', 'opens', 'closes'],
        );
        final val = OpeningHours(
          weekday: $checkedConvert('weekday', (v) => (v as num).toInt()),
          opens: $checkedConvert('opens', (v) => v as String),
          closes: $checkedConvert('closes', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$OpeningHoursToJson(OpeningHours instance) =>
    <String, dynamic>{
      'weekday': instance.weekday,
      'opens': instance.opens,
      'closes': instance.closes,
    };
