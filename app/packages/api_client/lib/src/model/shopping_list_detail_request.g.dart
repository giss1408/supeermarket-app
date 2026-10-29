// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_detail_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoppingListDetailRequest _$ShoppingListDetailRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'ShoppingListDetailRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['name'],
        );
        final val = ShoppingListDetailRequest(
          name: $checkedConvert('name', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$ShoppingListDetailRequestToJson(
        ShoppingListDetailRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
    };
