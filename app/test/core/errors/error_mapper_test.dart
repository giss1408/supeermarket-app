import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/errors/error_mapper.dart';

final _req = RequestOptions(path: '/x');

DioException _withResponse(Object? data, int status) => DioException(
      requestOptions: _req,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: _req,
        statusCode: status,
        data: data,
      ),
    );

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Object;

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  group('mapDioException', () {
    test('validation fixture -> ApiError with fields', () {
      final e = mapDioException(
        _withResponse(_fixture('error_validation.json'), 400),
      );
      expect(e, isA<ApiError>());
      e as ApiError;
      expect(e.code, 'validation_error');
      expect(e.status, 400);
      expect(e.detail, 'Invalid input.');
      expect(e.fields['password'], hasLength(3));
      expect(
        e.fields['password']!.first,
        startsWith('Ce mot de passe est trop court'),
      );
    });

    test('not_found fixture -> not_found', () {
      final e = mapDioException(
        _withResponse(_fixture('error_not_found.json'), 404),
      );
      expect((e as ApiError).code, 'not_found');
      expect(e.status, 404);
      expect(e.fields, isEmpty);
    });

    test('string JSON body is decoded', () {
      final e = mapDioException(
        _withResponse('{"code":"throttled","detail":"x","fields":{}}', 429),
      );
      expect((e as ApiError).code, 'throttled');
    });

    // Decision: a response with an unusable body still proves the server was
    // reached, so it is an ApiError(code: 'unknown', status) rather than UnknownError.
    test('non-JSON body with 502 -> ApiError unknown', () {
      final e = mapDioException(_withResponse('<html>', 502));
      expect(e, isA<ApiError>());
      e as ApiError;
      expect(e.code, 'unknown');
      expect(e.status, 502);
      expect(e.fields, isEmpty);
      expect(e.detail, isNull);
    });

    test('JSON body not in the error shape -> ApiError unknown', () {
      final e = mapDioException(_withResponse({'foo': 'bar'}, 500));
      expect((e as ApiError).code, 'unknown');
      expect(e.status, 500);
      final e2 = mapDioException(_withResponse(<Object?>[1, 2], 500));
      expect((e2 as ApiError).code, 'unknown');
    });

    test('response without status code -> UnknownError', () {
      final e = mapDioException(
        DioException(
          requestOptions: _req,
          response: Response<Object?>(requestOptions: _req, data: '<html>'),
        ),
      );
      expect(e, isA<UnknownError>());
    });

    test('connection error / unknown without response -> NetworkError', () {
      expect(
        mapDioException(
          DioException(
            requestOptions: _req,
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkError>(),
      );
      expect(
        mapDioException(
          DioException(
            requestOptions: _req,
            type: DioExceptionType.unknown,
            error: const SocketException('no route'),
          ),
        ),
        isA<NetworkError>(),
      );
    });

    test('timeouts -> AppTimeoutError', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapDioException(DioException(requestOptions: _req, type: t)),
          isA<AppTimeoutError>(),
          reason: '$t',
        );
      }
    });

    test('cancel, bad certificate, other unknown -> UnknownError', () {
      for (final t in [
        DioExceptionType.cancel,
        DioExceptionType.badCertificate
      ]) {
        expect(
          mapDioException(DioException(requestOptions: _req, type: t)),
          isA<UnknownError>(),
          reason: '$t',
        );
      }
      expect(
        mapDioException(
          DioException(
            requestOptions: _req,
            type: DioExceptionType.unknown,
            error: StateError('boom'),
          ),
        ),
        isA<UnknownError>(),
      );
    });
  });

  group('userMessage', () {
    const codes = [
      'validation_error',
      'not_authenticated',
      'permission_denied',
      'not_found',
      'throttled',
      'conflict',
      'server_error',
      'csrf_failed',
      'bad_request',
      'unsupported_media_type',
    ];
    const englishDetail = 'SERVER-ENGLISH-DETAIL Invalid input.';

    test('each known code gives a distinct non-empty French message', () {
      final messages = <String>{};
      for (final c in codes) {
        final m = userMessage(
          ApiError(
            code: c,
            status: 400,
            fields: const {},
            detail: englishDetail,
          ),
          l,
        );
        expect(m, isNotEmpty);
        expect(m, isNot(contains('Invalid input')));
        expect(m, isNot(contains('SERVER-ENGLISH-DETAIL')));
        messages.add(m);
      }
      expect(messages, hasLength(codes.length));
    });

    test('throttled message', () {
      final m = userMessage(
        const ApiError(code: 'throttled', status: 429, fields: {}),
        l,
      );
      expect(m, contains('Trop de requêtes'));
    });

    test('unknown code -> generic, differs from the known ones', () {
      final m = userMessage(
        const ApiError(
          code: 'whatever',
          status: 418,
          fields: {},
          detail: englishDetail,
        ),
        l,
      );
      expect(m, l.errorGeneric);
      expect(m, isNot(contains('SERVER')));
      expect(
        userMessage(UnknownError(StateError('x')), l),
        l.errorGeneric,
      );
    });

    test('network and timeout messages', () {
      expect(
        userMessage(const NetworkError(), l),
        'Pas de connexion. Vérifiez votre réseau et réessayez.',
      );
      expect(
        userMessage(const AppTimeoutError(), l),
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    });

    test('validation keeps fields and message never shows detail', () {
      final e =
          mapDioException(_withResponse(_fixture('error_validation.json'), 400))
              as ApiError;
      expect(e.fields, isNotEmpty);
      expect(userMessage(e, l), isNot(contains('Invalid input')));
    });
  });
}
