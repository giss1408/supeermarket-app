// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opening_hours_write_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpeningHoursWriteRequest _$OpeningHoursWriteRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'OpeningHoursWriteRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['weekday', 'opens', 'closes'],
        );
        final val = OpeningHoursWriteRequest(
          weekday: $checkedConvert('weekday', (v) => (v as num).toInt()),
          opens: $checkedConvert('opens', (v) => v as String),
          closes: $checkedConvert('closes', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$OpeningHoursWriteRequestToJson(
        OpeningHoursWriteRequest instance) =>
    <String, dynamic>{
      'weekday': instance.weekday,
      'opens': instance.opens,
      'closes': instance.closes,
    };
