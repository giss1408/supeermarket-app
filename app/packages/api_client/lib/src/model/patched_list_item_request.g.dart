// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_list_item_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedListItemRequest _$PatchedListItemRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedListItemRequest',
      json,
      ($checkedConvert) {
        final val = PatchedListItemRequest(
          product: $checkedConvert('product', (v) => (v as num?)?.toInt()),
          text: $checkedConvert('text', (v) => v as String?),
          quantity: $checkedConvert('quantity', (v) => (v as num?)?.toInt()),
          checked: $checkedConvert('checked', (v) => v as bool?),
        );
        return val;
      },
    );

Map<String, dynamic> _$PatchedListItemRequestToJson(
        PatchedListItemRequest instance) =>
    <String, dynamic>{
      if (instance.product case final value?) 'product': value,
      if (instance.text case final value?) 'text': value,
      if (instance.quantity case final value?) 'quantity': value,
      if (instance.checked case final value?) 'checked': value,
    };
