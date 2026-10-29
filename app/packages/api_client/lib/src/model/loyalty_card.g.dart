// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loyalty_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoyaltyCard _$LoyaltyCardFromJson(Map<String, dynamic> json) => $checkedCreate(
      'LoyaltyCard',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['number', 'barcode_value'],
        );
        final val = LoyaltyCard(
          number: $checkedConvert('number', (v) => v as String),
          barcodeValue: $checkedConvert('barcode_value', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {'barcodeValue': 'barcode_value'},
    );

Map<String, dynamic> _$LoyaltyCardToJson(LoyaltyCard instance) =>
    <String, dynamic>{
      'number': instance.number,
      'barcode_value': instance.barcodeValue,
    };
