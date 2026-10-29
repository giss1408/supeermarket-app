//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'image_upload_result.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ImageUploadResult {
  /// Returns a new [ImageUploadResult] instance.
  ImageUploadResult({
    required this.url,
    required this.name,
  });

  @JsonKey(
    name: r'url',
    required: true,
    includeIfNull: false,
  )
  final String url;

  @JsonKey(
    name: r'name',
    required: true,
    includeIfNull: false,
  )
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageUploadResult && other.url == url && other.name == name;

  @override
  int get hashCode => url.hashCode + name.hashCode;

  factory ImageUploadResult.fromJson(Map<String, dynamic> json) =>
      _$ImageUploadResultFromJson(json);

  Map<String, dynamic> toJson() => _$ImageUploadResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
