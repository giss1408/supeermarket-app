// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_item_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListItemRequest _$ListItemRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ListItemRequest',
      json,
      ($checkedConvert) {
        final val = ListItemRequest(
          product: $checkedConvert('product', (v) => (v as num?)?.toInt()),
          text: $checkedConvert('text', (v) => v as String?),
          quantity: $checkedConvert('quantity', (v) => (v as num?)?.toInt()),
          checked: $checkedConvert('checked', (v) => v as bool?),
        );
        return val;
      },
    );

Map<String, dynamic> _$ListItemRequestToJson(ListItemRequest instance) =>
    <String, dynamic>{
      if (instance.product case final value?) 'product': value,
      if (instance.text case final value?) 'text': value,
      if (instance.quantity case final value?) 'quantity': value,
      if (instance.checked case final value?) 'checked': value,
    };
