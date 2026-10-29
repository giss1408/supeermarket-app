//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `customer` - Customer * `staff` - Staff
enum RoleEnum {
  /// * `customer` - Customer * `staff` - Staff
  @JsonValue(r'customer')
  customer(r'customer'),

  /// * `customer` - Customer * `staff` - Staff
  @JsonValue(r'staff')
  staff(r'staff');

  const RoleEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
