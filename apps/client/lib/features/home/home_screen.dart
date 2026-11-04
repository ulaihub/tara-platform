import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';

/// Accueil de l'expéditeur. Écran suivant de la phase 5 (commande, suivi) : pour l'instant,
/// salutation et déconnexion.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.me});

  final Me me;

  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final first = (me.fullName ?? '').split(' ').first;
    return TaraScreen(
      blobs: _blobs,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.hello(first), style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            if (me.merchant != null) ...[
              const SizedBox(height: 6),
              Text(me.merchant!.shopName, style: TaraText.body.copyWith(color: c.textSecondary)),
            ],
            const Spacer(),
            TaraLink(label: l.logout, onPressed: () => ref.read(authControllerProvider.notifier).logout()),
          ],
        ),
      ),
    );
  }
}
