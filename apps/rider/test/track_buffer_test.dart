import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/track_buffer.dart';

const offline = ApiException(code: ApiException.network, message: 'hors ligne');
const notFound = ApiException(code: 'ORDER_NOT_FOUND', message: '', status: 404);

GeoPoint at(int seconds, {bool mocked = false}) => GeoPoint(
  latitude: 4.05,
  longitude: 9.7,
  recordedAt: DateTime.utc(2026, 11, 4, 9).add(Duration(seconds: seconds)),
  accuracy: 8,
  mocked: mocked,
);

void main() {
  late MemoryKeyValueStore store;
  late List<(String, List<Json>)> uploads;
  Object? failure;
  String? orderId;

  TrackBuffer buffer() => TrackBuffer(
    store: store,
    upload: (id, points) async {
      if (failure != null) throw failure!;
      uploads.add((id, points));
    },
    activeOrderId: () => orderId,
  );

  setUp(() {
    store = MemoryKeyValueStore();
    uploads = [];
    failure = null;
    orderId = 'course-1';
  });

  test('hors course : rien n’est gardé', () async {
    orderId = null;
    final track = buffer();
    await track.add(at(0));
    expect(track.pendingCount, 0);
  });

  test('positions sans réseau gardées, retrouvées après redémarrage, envoyées en lot', () async {
    await buffer().add(at(0));
    final restarted = buffer();
    await restarted.add(at(10, mocked: true));
    await restarted.flush();
    expect(uploads, hasLength(1));
    expect(uploads.single.$1, 'course-1');
    expect(uploads.single.$2.map((p) => p['recordedAt']), ['2026-11-04T09:00:00.000Z', '2026-11-04T09:00:10.000Z']);
    expect(uploads.single.$2.last['mocked'], isTrue);
    expect(restarted.pendingCount, 0);
    expect(await store.read('tara.track-buffer'), isNull);
  });

  test('toujours sans réseau : on garde ; course introuvable : on écarte', () async {
    final track = buffer();
    await track.add(at(0));
    failure = offline;
    await track.flush();
    expect(track.pendingCount, 1);
    failure = notFound;
    await track.flush();
    expect(track.pendingCount, 0);
  });

  test('au plus deux heures par course : les plus anciennes cèdent la place', () async {
    final track = buffer();
    for (var i = 0; i < TrackBuffer.maxPoints + 5; i++) {
      await track.add(at(i * 10));
    }
    expect(track.pendingCount, TrackBuffer.maxPoints);
    await track.flush();
    expect(uploads.single.$2.first['recordedAt'], '2026-11-04T09:00:50.000Z');
  });
}
