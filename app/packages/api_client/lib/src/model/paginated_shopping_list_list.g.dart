// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_shopping_list_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedShoppingListList _$PaginatedShoppingListListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedShoppingListList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedShoppingListList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedShoppingListListToJson(
        PaginatedShoppingListList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
