import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comparaison des captures avec une petite tolérance : l'anticrénelage des flous et des
/// dégradés peut varier d'un pixel entre deux machines Linux. Au-delà, l'écart est réel.
const _tolerance = 0.002; // 0,2 % des pixels

/// À appeler depuis `test/flutter_test_config.dart` de chaque app.
Future<void> tolerantGoldens(FutureOr<void> Function() testMain) async {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(comparator.basedir.resolve('golden_test.dart'));
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
