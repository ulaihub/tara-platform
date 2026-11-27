import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tara_core/codes/pickup_qr.dart';
import 'package:tara_ui/tara_colors.dart';

/// QR du code d'enlèvement (maquette Scanner) : le livreur le lit avec son app au lieu de
/// taper les chiffres. Noir sur blanc dans les deux thèmes (lisible par la caméra), petite
/// pastille Tara au centre (le QR la tolère : correction d'erreur élevée).
class PickupQr extends StatelessWidget {
  const PickupQr({super.key, required this.reference, required this.code, this.size = 140});

  final String reference;
  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = size * .2;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .057),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .1)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: pickupQrPayload(reference, code),
              padding: EdgeInsets.zero,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16120E)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF16120E),
              ),
            ),
            Container(
              width: mark,
              height: mark,
              padding: EdgeInsets.all(mark * .15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(mark * .27)),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(mark * .2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
