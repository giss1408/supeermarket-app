import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart' as api;
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/paging.dart';

Map<String, dynamic> fixture(String name) {
  final text = File('test/fixtures/$name.json').readAsStringSync();
  return json.decode(text) as Map<String, dynamic>;
}

void main() {
  group('fixtures parse with the generated models', () {
    test('flyers_current', () {
      final flyer = api.FlyerDetail.fromJson(fixture('flyers_current'));
      expect(flyer.offers, isNotEmpty);
      final offer = flyer.offers.first;
      // Money stays a String, never a number.
      expect(offer.price, isA<String>());
      expect(offer.price, '750.00');
      expect(offer.oldPrice, '1000.00');
      expect(flyer.offers.any((o) => o.oldPrice == null), isTrue);
      expect(offer.product.image, isNull);
    });

    test('flyers_list', () {
      final page = api.PaginatedFlyerListList.fromJson(fixture('flyers_list'));
      expect(page.results, isNotEmpty);
      expect(page.next, isNull);
      expect(page.previous, isNull);
    });

    test('offers_list', () {
      final page = api.PaginatedOfferList.fromJson(fixture('offers_list'));
      expect(page.results, isNotEmpty);
      expect(page.results.first.price, isA<String>());
      expect(page.next, isNull);
    });

    test('categories_list', () {
      final page = api.PaginatedCategoryList.fromJson(
        fixture('categories_list'),
      );
      expect(page.results.length, 6);
    });

    test('stores_list has null distance_km without coordinates', () {
      final page = api.PaginatedStoreList.fromJson(fixture('stores_list'));
      expect(page.results, isNotEmpty);
      expect(page.results.every((s) => s.distanceKm == null), isTrue);
      expect(page.results.first.latitude, isA<String>());
    });

    test('stores_list_with_distance has numeric distance_km', () {
      final page = api.PaginatedStoreList.fromJson(
        fixture('stores_list_with_distance'),
      );
      expect(page.results.every((s) => s.distanceKm != null), isTrue);
      expect(page.results.first.distanceKm, isA<double>());
    });

    test('store_detail', () {
      final store = api.StoreDetail.fromJson(fixture('store_detail'));
      expect(store.openingHours, isNotEmpty);
    });

    test('payment_methods', () {
      final page = api.PaginatedPaymentMethodList.fromJson(
        fixture('payment_methods'),
      );
      expect(page.results, isNotEmpty);
      final keys = page.results.first.toJson().keys.toSet();
      expect(keys.contains('currentPassword'), isFalse);
      expect(keys.contains('current_password'), isFalse);
      expect(
          fixture('payment_methods').toString(), isNot(contains('password')));
    });

    test('list_detail: product summary and free text item', () {
      final list = api.ShoppingListDetail.fromJson(fixture('list_detail'));
      expect(list.name, 'Courses');
      expect(list.items, hasLength(2));
      final linked = list.items.firstWhere((i) => i.product != null);
      expect(linked.product!.name, isNotEmpty);
      expect(linked.product!.unit, isNotNull);
      expect(linked.product!.image, isNull);
      final free = list.items.firstWhere((i) => i.product == null);
      expect(free.text, 'Pain frais');
    });

    test('me, me_card, auth_login', () {
      final me = api.Me.fromJson(fixture('me'));
      expect(me.email, 'customer@example.com');
      final card = api.Card.fromJson(fixture('me_card'));
      expect(card.number, card.barcodeValue);
      final tokens = api.TokenObtainPair.fromJson(fixture('auth_login'));
      expect(tokens.access, 'access-token-fixture');
      expect(tokens.refresh, 'refresh-token-fixture');
    });

    test('error fixtures', () {
      final validation = api.Error.fromJson(fixture('error_validation'));
      expect(validation.code, 'validation_error');
      expect(validation.detail, isNotEmpty);
      expect(validation.fields['password'], isA<List<String>>());
      expect(validation.fields['password'], isNotEmpty);
      final notFound = api.Error.fromJson(fixture('error_not_found'));
      expect(notFound.code, 'not_found');
      expect(notFound.fields, isEmpty);
    });
  });

  group('request models serialise', () {
    test('list item request sends product as an integer', () {
      final body = api.ListItemRequest(product: 12, quantity: 3).toJson();
      expect(body['product'], 12);
      expect(body['product'], isA<int>());
      expect(body['quantity'], 3);
    });

    test('register request has no role property', () {
      final body = api.RegisterRequest(
        email: 'a@example.com',
        password: 'Mot-de-passe-42',
        name: 'A B',
      ).toJson();
      expect(body.keys, containsAll(['email', 'password']));
      expect(body.containsKey('role'), isFalse);
    });
  });

  group('pagination', () {
    test('a synthetic page with a next cursor feeds the paging helper', () {
      final page = api.PaginatedOfferList.fromJson({
        'next': 'https://host/api/v1/offers?cursor=abc%3D&page=1',
        'previous': null,
        'results': <Object?>[],
      });
      final result = toPageResult(page.results, page.next);
      expect(result.next, 'abc=');
      expect(result.items, isEmpty);
    });
  });
}
