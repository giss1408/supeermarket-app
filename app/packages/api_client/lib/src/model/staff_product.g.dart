// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffProduct _$StaffProductFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffProduct',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'name', 'category', 'image'],
        );
        final val = StaffProduct(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String?),
          category: $checkedConvert('category', (v) => (v as num).toInt()),
          unit: $checkedConvert('unit', (v) => v as String?),
          ean: $checkedConvert('ean', (v) => v as String?),
          image: $checkedConvert('image', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$StaffProductToJson(StaffProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.description case final value?) 'description': value,
      'category': instance.category,
      if (instance.unit case final value?) 'unit': value,
      if (instance.ean case final value?) 'ean': value,
      'image': instance.image,
    };
