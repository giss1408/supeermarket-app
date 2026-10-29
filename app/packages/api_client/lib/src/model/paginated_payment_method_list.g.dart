// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_payment_method_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedPaymentMethodList _$PaginatedPaymentMethodListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedPaymentMethodList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedPaymentMethodList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedPaymentMethodListToJson(
        PaginatedPaymentMethodList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
