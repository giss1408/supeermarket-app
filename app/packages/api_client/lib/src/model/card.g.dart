// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Card _$CardFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Card',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['number', 'barcode_value'],
        );
        final val = Card(
          number: $checkedConvert('number', (v) => v as String),
          barcodeValue: $checkedConvert('barcode_value', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {'barcodeValue': 'barcode_value'},
    );

Map<String, dynamic> _$CardToJson(Card instance) => <String, dynamic>{
      'number': instance.number,
      'barcode_value': instance.barcodeValue,
    };
