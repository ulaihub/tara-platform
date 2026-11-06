import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';

class Routes implements HttpClientAdapter {
  Routes(this.handler);
  final (int, Object) Function(RequestOptions options) handler;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MemoryKeyValueStore storage;
  setUp(() => storage = MemoryKeyValueStore());

  ProviderContainer container(Routes routes) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'https://api.test',
            store: ref.watch(sessionStoreProvider),
            dio: Dio(BaseOptions(baseUrl: 'https://api.test/v1'))..httpClientAdapter = routes,
            onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  const session = {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token-0123456789',
    'expiresIn': 900,
    'isNewUser': false,
    'referralApplied': false,
    'user': {
      'id': 'u1',
      'phone': '+237690000001',
      'fullName': 'Awa',
      'roles': ['CUSTOMER', 'RIDER'],
      'locale': 'FR',
    },
  };

  test('connexion par code SMS puis déconnexion', () async {
    final routes = Routes(
      (o) => switch (o.path) {
        '/auth/otp' => (201, {'challengeId': 'c1', 'expiresAt': '2026-11-03T10:00:00.000Z', 'resendAfterSeconds': 60}),
        '/auth/otp/verify' => (200, session),
        _ => (204, <String, Object?>{}),
      },
    );
    final c = container(routes);
    expect(await c.read(authControllerProvider.future), AuthStatus.signedOut);
    final auth = c.read(authControllerProvider.notifier);
    final challenge = await auth.requestCode('690000001');
    final result = await auth.verifyCode(challengeId: challenge.challengeId, code: '123456');
    expect(result.user.isRider, isTrue);
    expect(c.read(authControllerProvider).value, AuthStatus.signedIn);
    expect((await c.read(sessionStoreProvider).read())?.accessToken, 'access-token');

    await auth.logout();
    expect(routes.paths.last, '/auth/logout');
    expect(c.read(authControllerProvider).value, AuthStatus.signedOut);
    expect(await c.read(sessionStoreProvider).read(), isNull);
  });

  test('session refusée par le serveur : retour à la connexion', () async {
    await SessionStore(storage).write(
      StoredSession(
        accessToken: 'old',
        refreshToken: 'refresh-old-0123456789',
        accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final routes = Routes(
      (_) => (
        401,
        {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
        },
      ),
    );
    final c = container(routes);
    expect(await c.read(authControllerProvider.future), AuthStatus.signedIn);
    await expectLater(c.read(riderApiProvider).presence(), throwsA(anything));
    expect(c.read(authControllerProvider).value, AuthStatus.signedOut);
  });

  test('réglages : valeurs par défaut hors connexion, puis celles du serveur gardées', () async {
    final routes = Routes(
      (o) => (
        200,
        {
          'country': {'code': 'CM', 'dialCode': '+237', 'currency': 'XAF'},
          'safetyHotline': '+237699999999',
          'supportPhone': '+237622222222',
          'mobileMoneyOperators': [
            {'code': 'MTN', 'name': 'MTN MoMo'},
          ],
          'offerTimeoutSeconds': 25,
        },
      ),
    );
    await SessionStore(storage).write(
      StoredSession(
        accessToken: 'a',
        refreshToken: 'refresh-a-0123456789',
        accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final c = container(routes);
    final first = await c.read(riderConfigProvider.future);
    expect(first.safetyHotline, '+237640114064');
    await c.read(riderConfigProvider.notifier).refresh();
    expect(c.read(riderConfigProvider).value?.safetyHotline, '+237699999999');

    // Nouvelle ouverture sans réseau : la dernière configuration connue.
    final offline = container(
      Routes(
        (_) => (
          503,
          {
            'error': {'code': 'INTERNAL_ERROR', 'message': ''},
          },
        ),
      ),
    );
    final cached = await offline.read(riderConfigProvider.future);
    expect(cached.supportPhone, '+237622222222');
    expect(cached.offerTimeoutSeconds, 25);
  });
}
