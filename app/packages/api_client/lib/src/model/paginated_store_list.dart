//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/store.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_store_list.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedStoreList {
  /// Returns a new [PaginatedStoreList] instance.
  PaginatedStoreList({
    this.next,
    this.previous,
    required this.results,
  });

  @JsonKey(
    name: r'next',
    required: false,
    includeIfNull: false,
  )
  final String? next;

  @JsonKey(
    name: r'previous',
    required: false,
    includeIfNull: false,
  )
  final String? previous;

  @JsonKey(
    name: r'results',
    required: true,
    includeIfNull: false,
  )
  final List<Store> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedStoreList &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedStoreList.fromJson(Map<String, dynamic> json) =>
      _$PaginatedStoreListFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedStoreListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
