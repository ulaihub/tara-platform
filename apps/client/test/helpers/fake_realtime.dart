import 'dart:async';

import 'package:tara_core/api/models.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_core/session/session_store.dart';

/// Temps réel sans réseau : les tests poussent eux-mêmes les événements du serveur.
class FakeRealtime extends RealtimeClient {
  FakeRealtime() : super(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore()));

  final _events = StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get stream => _events.stream;

  @override
  void connect() {}

  void emit(String name, Json payload) => _events.add(RealtimeEvent(name, payload));
}
