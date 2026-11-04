//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `customer` - Customer * `retailer_staff` - Retailer staff * `platform_admin` - Platform admin
enum RoleEnum {
  /// * `customer` - Customer * `retailer_staff` - Retailer staff * `platform_admin` - Platform admin
  @JsonValue(r'customer')
  customer(r'customer'),

  /// * `customer` - Customer * `retailer_staff` - Retailer staff * `platform_admin` - Platform admin
  @JsonValue(r'retailer_staff')
  retailerStaff(r'retailer_staff'),

  /// * `customer` - Customer * `retailer_staff` - Retailer staff * `platform_admin` - Platform admin
  @JsonValue(r'platform_admin')
  platformAdmin(r'platform_admin');

  const RoleEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
