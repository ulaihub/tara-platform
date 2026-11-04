import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page plein écran qui garde les fournisseurs de l'écran qui l'ouvre, même quand le
/// ProviderScope est posé sous le MaterialApp (cas des tests).
MaterialPageRoute<T> scopedPage<T>(BuildContext context, WidgetBuilder builder) {
  final container = ProviderScope.containerOf(context, listen: false);
  return MaterialPageRoute<T>(
    builder: (context) => UncontrolledProviderScope(container: container, child: builder(context)),
  );
}
