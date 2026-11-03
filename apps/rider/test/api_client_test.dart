import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/core/api/api_client.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/session/session_store.dart';

/// Faux serveur : répond selon la route, garde les requêtes reçues.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late SessionStore store;
  setUp(() => store = SessionStore(MemoryKeyValueStore()));

  ApiClient client(FakeServer server, {void Function()? expired}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))..httpClientAdapter = server;
    return ApiClient(
      baseUrl: 'https://api.test',
      store: store,
      dio: dio,
      locale: () => 'en',
      onSessionExpired: expired,
    );
  }

  StoredSession session(String access, {Duration validFor = const Duration(minutes: 10)}) => StoredSession(
    accessToken: access,
    refreshToken: 'refresh-$access-0123456789',
    accessExpiresAt: DateTime.now().add(validFor),
  );

  test('ajoute le jeton et la langue', () async {
    await store.write(session('A'));
    final server = FakeServer((_) => json(200, {'ok': true}));
    expect(await client(server).get('/rider/config'), {'ok': true});
    expect(server.requests.single.headers['Authorization'], 'Bearer A');
    expect(server.requests.single.headers['Accept-Language'], 'en');
  });

  test('renouvelle le jeton une seule fois pour des requêtes simultanées refusées', () async {
    await store.write(session('OLD'));
    var refreshes = 0;
    final server = FakeServer((options) {
      if (options.path == '/auth/refresh') {
        refreshes++;
        return json(200, {'accessToken': 'NEW', 'refreshToken': 'refresh-new-0123456789', 'expiresIn': 900});
      }
      final auth = options.headers['Authorization'];
      return auth == 'Bearer NEW'
          ? json(200, {'path': options.path})
          : json(401, {
              'error': {'code': 'UNAUTHENTICATED', 'message': 'Session expired'},
            });
    });
    final api = client(server);
    final results = await Future.wait([api.get('/a'), api.get('/b'), api.get('/c')]);
    expect(results, [
      {'path': '/a'},
      {'path': '/b'},
      {'path': '/c'},
    ]);
    expect(refreshes, 1);
    expect((await store.read())?.accessToken, 'NEW');
  });

  test('renouvelle avant l’expiration du jeton', () async {
    await store.write(session('OLD', validFor: const Duration(seconds: 5)));
    final server = FakeServer(
      (options) => options.path == '/auth/refresh'
          ? json(200, {'accessToken': 'NEW', 'refreshToken': 'refresh-new-0123456789', 'expiresIn': 900})
          : json(200, {'auth': options.headers['Authorization']}),
    );
    expect(await client(server).get('/x'), {'auth': 'Bearer NEW'});
  });

  test('session refusée : effacée et retour à l’accueil', () async {
    await store.write(session('OLD'));
    var expired = 0;
    final server = FakeServer(
      (_) => json(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'nope'},
      }),
    );
    await expectLater(
      client(server, expired: () => expired++).get('/x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SESSION_EXPIRED')),
    );
    expect(await store.read(), isNull);
    expect(expired, 1);
  });

  test('erreur métier et coupure réseau', () async {
    final server = FakeServer(
      (_) => json(409, {
        'error': {
          'code': 'COLLECTION_REQUIRED',
          'message': 'Encaissez d’abord',
          'details': {'amount': 12500},
        },
      }),
    );
    await expectLater(
      client(server).post('/rider/orders/1/deliver', auth: false),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'COLLECTION_REQUIRED')
            .having((e) => e.details['amount'], 'details', 12500),
      ),
    );
    final offline = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))
      ..httpClientAdapter = FakeServer(
        (options) => throw DioException.connectionError(requestOptions: options, reason: 'no route'),
      );
    final api = ApiClient(baseUrl: 'https://api.test', store: store, dio: offline);
    await expectLater(
      api.get('/x', auth: false),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'réseau', true)),
    );
  });

  test('identifiant d’installation stable', () async {
    final first = await store.installationId();
    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await store.installationId(), first);
  });
}
