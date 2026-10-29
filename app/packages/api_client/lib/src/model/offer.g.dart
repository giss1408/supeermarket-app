// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Offer _$OfferFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Offer',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['id', 'flyer', 'price', 'product'],
        );
        final val = Offer(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          flyer: $checkedConvert('flyer', (v) => (v as num).toInt()),
          price: $checkedConvert('price', (v) => v as String),
          oldPrice: $checkedConvert('old_price', (v) => v as String?),
          badgeText: $checkedConvert('badge_text', (v) => v as String?),
          validFrom: $checkedConvert('valid_from',
              (v) => v == null ? null : DateTime.parse(v as String)),
          validTo: $checkedConvert('valid_to',
              (v) => v == null ? null : DateTime.parse(v as String)),
          product: $checkedConvert(
              'product', (v) => Product.fromJson(v as Map<String, dynamic>)),
        );
        return val;
      },
      fieldKeyMap: const {
        'oldPrice': 'old_price',
        'badgeText': 'badge_text',
        'validFrom': 'valid_from',
        'validTo': 'valid_to'
      },
    );

Map<String, dynamic> _$OfferToJson(Offer instance) => <String, dynamic>{
      'id': instance.id,
      'flyer': instance.flyer,
      'price': instance.price,
      if (instance.oldPrice case final value?) 'old_price': value,
      if (instance.badgeText case final value?) 'badge_text': value,
      if (instance.validFrom?.toIso8601String() case final value?)
        'valid_from': value,
      if (instance.validTo?.toIso8601String() case final value?)
        'valid_to': value,
      'product': instance.product.toJson(),
    };
