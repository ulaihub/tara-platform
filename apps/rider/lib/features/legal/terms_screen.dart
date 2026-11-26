import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/terms_flow.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';

/// Libellés de l'acceptation des conditions, dans la langue de l'app.
TermsStrings termsStrings(BuildContext context) {
  final l = AppLocalizations.of(context);
  return TermsStrings(
    back: l.back,
    retry: l.retry,
    title: l.termsTitle,
    updateTitle: l.termsUpdateTitle,
    signupIntro: l.termsSignupIntro,
    updateIntro: l.termsUpdateIntro,
    later: l.termsLater,
    end: l.termsEnd,
    scrollFirst: l.termsScrollFirst,
    checkPrefix: l.termsCheckPrefix,
    checkTerms: l.termsCheckTerms,
    checkAnd: l.termsCheckAnd,
    checkPrivacy: l.termsCheckPrivacy,
    createAccount: l.termsCreateAccount,
    acceptUpdate: l.termsAcceptUpdate,
    acceptedOn: l.termsAcceptedOn,
    versionLine: l.termsVersionLine,
    errorText: (error) => errorMessage(context, error),
    signupKicker: l.termsSignupKicker,
    readPercent: l.termsReadPercent,
  );
}

/// Conditions des livreurs et politique de confidentialité, lues en entier puis acceptées.
/// Inscription : le code de connexion signe. Nouvelle version : la case suffit (compte déjà
/// connecté) ; « Plus tard » laisse finir la course en cours, sans nouvelle course.
class TermsScreen extends ConsumerWidget {
  const TermsScreen.signup({
    super.key,
    required Future<void> Function(Map<String, String> versions) onAccept,
    this.onBack,
  }) : onSignup = onAccept,
       onLater = null,
       onSigned = null;

  const TermsScreen.update({super.key, this.onLater, required this.onSigned}) : onSignup = null, onBack = null;

  final Future<void> Function(Map<String, String> versions)? onSignup;
  final VoidCallback? onBack;
  final VoidCallback? onLater;
  final VoidCallback? onSigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(legalApiProvider);
    final strings = termsStrings(context);
    if (onSignup case final accept?) {
      return TermsAcceptScreen.signup(strings: strings, load: api.appDocuments, onAccept: accept, onBack: onBack);
    }
    return TermsAcceptScreen.update(
      strings: strings,
      load: api.appDocuments,
      api: api,
      onLater: onLater,
      onSigned: () {
        ref.invalidate(termsStatusProvider);
        onSigned?.call();
      },
    );
  }
}

/// Lecture d'un texte en vigueur (lien de la connexion, profil).
class LegalTextScreen extends ConsumerWidget {
  const LegalTextScreen({super.key, required this.document, this.acceptedAt});

  /// livreurs ou confidentialite.
  final String document;
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LegalDocumentScreen(
    strings: termsStrings(context),
    load: () => ref.read(legalApiProvider).document(document),
    acceptedAt: acceptedAt,
  );
}

/// Nouvelle version à accepter, ouverte depuis l'app (passage en ligne refusé, profil) : la
/// page se ferme une fois acceptée ou remise à plus tard.
Future<void> openTermsUpdate(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push(
    scopedPage<void>(
      context,
      (route) =>
          TermsScreen.update(onLater: () => Navigator.of(route).pop(), onSigned: () => Navigator.of(route).pop()),
    ),
  );
}
