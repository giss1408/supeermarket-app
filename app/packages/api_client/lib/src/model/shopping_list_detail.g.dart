// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoppingListDetail _$ShoppingListDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ShoppingListDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'name',
            'items',
            'created_at',
            'updated_at'
          ],
        );
        final val = ShoppingListDetail(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          items: $checkedConvert(
              'items',
              (v) => (v as List<dynamic>)
                  .map((e) => ListItem.fromJson(e as Map<String, dynamic>))
                  .toList()),
          createdAt:
              $checkedConvert('created_at', (v) => DateTime.parse(v as String)),
          updatedAt:
              $checkedConvert('updated_at', (v) => DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {'createdAt': 'created_at', 'updatedAt': 'updated_at'},
    );

Map<String, dynamic> _$ShoppingListDetailToJson(ShoppingListDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
