import 'package:flutter/widgets.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/api_exception.dart';
import '../../l10n/app_localizations.dart';

/// Message d'erreur lisible : celui du serveur (déjà dans la langue du livreur), ou un
/// message de l'app pour une coupure réseau ou une erreur inattendue.
String errorMessage(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  if (error is ApiException) {
    if (error.isNetwork) return l.networkError;
    if (error.message.isNotEmpty) return error.message;
  }
  return l.genericError;
}

/// Ligne d'erreur sous un formulaire, annoncée par le lecteur d'écran.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: TaraIcon(TaraIcons.alertCircle, size: 16, color: c.dangerText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TaraText.label.copyWith(color: c.dangerText)),
          ),
        ],
      ),
    );
  }
}
