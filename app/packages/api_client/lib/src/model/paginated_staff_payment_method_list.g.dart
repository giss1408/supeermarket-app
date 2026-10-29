// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_staff_payment_method_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedStaffPaymentMethodList _$PaginatedStaffPaymentMethodListFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'PaginatedStaffPaymentMethodList',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['results'],
        );
        final val = PaginatedStaffPaymentMethodList(
          next: $checkedConvert('next', (v) => v as String?),
          previous: $checkedConvert('previous', (v) => v as String?),
          results: $checkedConvert(
              'results',
              (v) => (v as List<dynamic>)
                  .map((e) =>
                      StaffPaymentMethod.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$PaginatedStaffPaymentMethodListToJson(
        PaginatedStaffPaymentMethodList instance) =>
    <String, dynamic>{
      if (instance.next case final value?) 'next': value,
      if (instance.previous case final value?) 'previous': value,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
