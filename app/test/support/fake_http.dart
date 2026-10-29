import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeResponse {
  FakeResponse(this.status, [Object? body]) : body = jsonEncode(body ?? {});
  final int status;
  final String body;
}

class RecordedCall {
  RecordedCall(this.method, this.path, this.headers, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final String? body;

  String? get authorization => headers['Authorization'] as String?;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(
    RequestOptions options, int callNumber);

/// Scripted [HttpClientAdapter] that records every call.
class FakeAdapter implements HttpClientAdapter {
  final _routes = <(String, String, FakeHandler)>[];
  final calls = <RecordedCall>[];

  /// Called synchronously for every request before it is answered.
  void Function(RecordedCall call)? onCall;

  /// Routes match on method and path suffix; the LAST registration wins.
  void on(String method, String pathEnd, FakeHandler handler) =>
      _routes.insert(0, (method, pathEnd, handler));

  void reply(String method, String pathEnd, int status, [Object? body]) =>
      on(method, pathEnd, (_, __) => FakeResponse(status, body));

  List<RecordedCall> callsTo(String pathEnd) =>
      calls.where((c) => c.path.endsWith(pathEnd)).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = RecordedCall(
      options.method,
      options.uri.path,
      Map.of(options.headers),
      options.data is String ? options.data as String : null,
    );
    calls.add(call);
    onCall?.call(call);
    final number = calls.where((c) => c.path == call.path).length;
    for (final (method, end, handler) in _routes) {
      if (method == options.method && options.uri.path.endsWith(end)) {
        final r = await handler(options, number);
        return ResponseBody.fromString(
          r.body,
          r.status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode(errorBody('not_found')),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A handler that fails like a dead network.
FakeHandler offline() => (o, _) => throw DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
    );

Map<String, dynamic> errorBody(String code, [Map<String, List<String>>? f]) =>
    {'code': code, 'detail': 'secret server detail', 'fields': f ?? {}};
