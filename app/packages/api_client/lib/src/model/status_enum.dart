//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `draft` - Draft * `published` - Published
enum StatusEnum {
  /// * `draft` - Draft * `published` - Published
  @JsonValue(r'draft')
  draft(r'draft'),

  /// * `draft` - Draft * `published` - Published
  @JsonValue(r'published')
  published(r'published');

  const StatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
