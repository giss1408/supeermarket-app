// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opening_hours_write.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpeningHoursWrite _$OpeningHoursWriteFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OpeningHoursWrite',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['weekday', 'opens', 'closes'],
        );
        final val = OpeningHoursWrite(
          weekday: $checkedConvert('weekday', (v) => (v as num).toInt()),
          opens: $checkedConvert('opens', (v) => v as String),
          closes: $checkedConvert('closes', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$OpeningHoursWriteToJson(OpeningHoursWrite instance) =>
    <String, dynamic>{
      'weekday': instance.weekday,
      'opens': instance.opens,
      'closes': instance.closes,
    };
