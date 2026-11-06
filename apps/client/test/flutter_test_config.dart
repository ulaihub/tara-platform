import 'dart:async';

import 'package:tara_test/golden_config.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) => tolerantGoldens(testMain);
