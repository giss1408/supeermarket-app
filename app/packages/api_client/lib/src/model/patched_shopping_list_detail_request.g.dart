// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_shopping_list_detail_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedShoppingListDetailRequest _$PatchedShoppingListDetailRequestFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PatchedShoppingListDetailRequest',
      json,
      ($checkedConvert) {
        final val = PatchedShoppingListDetailRequest(
          name: $checkedConvert('name', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$PatchedShoppingListDetailRequestToJson(
        PatchedShoppingListDetailRequest instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
    };
