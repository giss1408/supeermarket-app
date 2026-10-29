//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'patched_me_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedMeRequest {
  /// Returns a new [PatchedMeRequest] instance.
  PatchedMeRequest({
    this.name,
  });

  @JsonKey(
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PatchedMeRequest && other.name == name;

  @override
  int get hashCode => name.hashCode;

  factory PatchedMeRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedMeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedMeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
