// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_me_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedMeRequest _$PatchedMeRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedMeRequest',
      json,
      ($checkedConvert) {
        final val = PatchedMeRequest(
          name: $checkedConvert('name', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$PatchedMeRequestToJson(PatchedMeRequest instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
    };
