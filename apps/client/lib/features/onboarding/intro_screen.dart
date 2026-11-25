import 'package:flutter/material.dart';
import 'package:tara_ui/components/intro.dart';

import '../../l10n/app_localizations.dart';
import 'intro_art.dart';

/// Présentation au premier lancement (maquettes Présentation · Envoyer, Suivre, Encaisser,
/// Deux comptes), avant la connexion. Vue une fois, elle ne revient plus.
class ClientIntroScreen extends StatelessWidget {
  const ClientIntroScreen({super.key, required this.onDone, this.initialPage = 0});

  final VoidCallback onDone;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IntroScreen(
      initialPage: initialPage,
      skip: l.introSkip,
      next: l.introNext,
      start: l.introStart,
      onDone: onDone,
      slides: [
        IntroSlide(kicker: l.introSendKicker, title: l.introSendTitle, body: l.introSendBody, illustration: const SendArt()),
        IntroSlide(
          kicker: l.introTrackKicker,
          title: l.introTrackTitle,
          body: l.introTrackBody,
          illustration: const TrackArt(),
        ),
        IntroSlide(
          kicker: l.introCollectKicker,
          title: l.introCollectTitle,
          body: l.introCollectBody,
          illustration: const CollectArt(),
        ),
        IntroSlide(
          kicker: l.introAccountsKicker,
          title: l.introAccountsTitle,
          body: l.introAccountsBody,
          illustration: const AccountsArt(),
        ),
      ],
    );
  }
}
