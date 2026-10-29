// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_obtain_pair_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenObtainPairRequest _$TokenObtainPairRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'TokenObtainPairRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['email', 'password'],
        );
        final val = TokenObtainPairRequest(
          email: $checkedConvert('email', (v) => v as String),
          password: $checkedConvert('password', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$TokenObtainPairRequestToJson(
        TokenObtainPairRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
    };
