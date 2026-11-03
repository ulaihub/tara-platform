import 'package:flutter/widgets.dart';

import '../../design/components/brand.dart';
import '../../design/components/layout.dart';
import '../../design/motion/effects.dart';
import '../../design/motion/liquid_background.dart';

/// Démarrage (écran non dessiné, proposé) : logo et gouttes, le temps de relire la session
/// et les réglages gardés sur le téléphone.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.1), size: 320, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 1.1), size: 280, colors: BlobSpec.warm, blur: 70, delay: Duration(seconds: 5)),
  ];

  @override
  Widget build(BuildContext context) {
    return const TaraScreen(
      blobs: _blobs,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [TaraLogo(width: 214), SizedBox(height: 36), GooLoader()],
        ),
      ),
    );
  }
}
