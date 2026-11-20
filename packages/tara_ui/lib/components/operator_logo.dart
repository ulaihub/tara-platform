import 'package:flutter/widgets.dart';

import '../tara_icons.dart';
import 'inputs.dart';

/// Logo officiel de l'opérateur Mobile Money (fichiers fournis par Tara), sur un carré
/// blanc arrondi. Code d'opérateur (`MTN`, `ORANGE`) ou moyen de paiement (`MOMO_MTN`,
/// `MOMO_ORANGE`). Autre code : icône de téléphone. Décoratif : le nom de l'opérateur est
/// toujours écrit à côté.
class OperatorLogo extends StatelessWidget {
  const OperatorLogo(this.code, {super.key, this.size = 24});

  final String code;
  final double size;

  static String? _asset(String code) => switch (code.toUpperCase()) {
    'MTN' || 'MOMO_MTN' => 'assets/brands/mtn_momo.png',
    'ORANGE' || 'MOMO_ORANGE' => 'assets/brands/orange_money.png',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final asset = _asset(code);
    final radius = BorderRadius.circular(size * .22);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: radius,
          border: Border.all(color: const Color.fromRGBO(22, 18, 14, .08)),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: asset == null
              ? Center(
                  child: TaraIcon(TaraIcons.phone, size: size * .6, color: const Color(0xFF16120E)),
                )
              : Image.asset(asset, package: 'tara_ui', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}

/// Choix d'opérateur avec son logo (recharge, retrait, paiement, encaissement).
ChoiceOption<String> operatorChoice(String code, String label) =>
    ChoiceOption(code, label, leading: OperatorLogo(code, size: 22));
