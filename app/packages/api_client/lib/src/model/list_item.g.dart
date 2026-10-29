// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListItem _$ListItemFromJson(Map<String, dynamic> json) => $checkedCreate(
      'ListItem',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'product', 'created_at', 'updated_at'],
        );
        final val = ListItem(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          product: $checkedConvert(
              'product',
              (v) => v == null
                  ? null
                  : ProductSummary.fromJson(v as Map<String, dynamic>)),
          text: $checkedConvert('text', (v) => v as String?),
          quantity: $checkedConvert('quantity', (v) => (v as num?)?.toInt()),
          checked: $checkedConvert('checked', (v) => v as bool?),
          createdAt:
              $checkedConvert('created_at', (v) => DateTime.parse(v as String)),
          updatedAt:
              $checkedConvert('updated_at', (v) => DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {'createdAt': 'created_at', 'updatedAt': 'updated_at'},
    );

Map<String, dynamic> _$ListItemToJson(ListItem instance) => <String, dynamic>{
      'id': instance.id,
      'product': instance.product?.toJson(),
      if (instance.text case final value?) 'text': value,
      if (instance.quantity case final value?) 'quantity': value,
      if (instance.checked case final value?) 'checked': value,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
