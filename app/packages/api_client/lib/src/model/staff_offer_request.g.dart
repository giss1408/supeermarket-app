// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_offer_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffOfferRequest _$StaffOfferRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StaffOfferRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['flyer', 'product', 'price'],
        );
        final val = StaffOfferRequest(
          flyer: $checkedConvert('flyer', (v) => (v as num).toInt()),
          product: $checkedConvert('product', (v) => (v as num).toInt()),
          price: $checkedConvert('price', (v) => v as String),
          oldPrice: $checkedConvert('old_price', (v) => v as String?),
          badgeText: $checkedConvert('badge_text', (v) => v as String?),
          sortOrder: $checkedConvert('sort_order', (v) => (v as num?)?.toInt()),
          validFrom: $checkedConvert('valid_from',
              (v) => v == null ? null : DateTime.parse(v as String)),
          validTo: $checkedConvert('valid_to',
              (v) => v == null ? null : DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {
        'oldPrice': 'old_price',
        'badgeText': 'badge_text',
        'sortOrder': 'sort_order',
        'validFrom': 'valid_from',
        'validTo': 'valid_to'
      },
    );

Map<String, dynamic> _$StaffOfferRequestToJson(StaffOfferRequest instance) =>
    <String, dynamic>{
      'flyer': instance.flyer,
      'product': instance.product,
      'price': instance.price,
      if (instance.oldPrice case final value?) 'old_price': value,
      if (instance.badgeText case final value?) 'badge_text': value,
      if (instance.sortOrder case final value?) 'sort_order': value,
      if (instance.validFrom?.toIso8601String() case final value?)
        'valid_from': value,
      if (instance.validTo?.toIso8601String() case final value?)
        'valid_to': value,
    };
