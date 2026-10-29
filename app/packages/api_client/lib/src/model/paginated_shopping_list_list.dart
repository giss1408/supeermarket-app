//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/shopping_list.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_shopping_list_list.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedShoppingListList {
  /// Returns a new [PaginatedShoppingListList] instance.
  PaginatedShoppingListList({
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
  final List<ShoppingList> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedShoppingListList &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedShoppingListList.fromJson(Map<String, dynamic> json) =>
      _$PaginatedShoppingListListFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedShoppingListListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
