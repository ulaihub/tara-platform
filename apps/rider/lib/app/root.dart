import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/models.dart';
import '../features/auth/code_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/common/error_text.dart';
import '../features/common/splash_screen.dart';
import '../features/common/status_screen.dart';
import '../features/home/home_flow.dart';
import '../features/legal/terms_screen.dart';
import '../features/onboarding/documents_controller.dart';
import '../features/onboarding/documents_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/profile_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

/// Dossier livreur du compte connecté ; null s'il n'a pas encore postulé. Relu à chaque
/// changement de session (jamais celui du compte précédent).
final riderProfileProvider = FutureProvider<RiderProfile?>((ref) async {
  ref.watch(authControllerProvider.select((auth) => auth.value));
  try {
    return await ref.read(riderApiProvider).profile();
  } on ApiException catch (error) {
    // Pas encore livreur : le rôle n'est pas accordé (403) ou le dossier n'existe pas.
    if (error.status == 403 || error.status == 404) return null;
    rethrow;
  }
});

/// Aiguillage selon la session et le dossier : connexion, inscription, vérification,
/// accueil. Parcours du prototype (passation §7).
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(riderRuntimeProvider);
    final auth = ref.watch(authControllerProvider);
    final Widget screen = switch (auth.value) {
      null => const SplashScreen(),
      AuthStatus.signedOut => const _AuthFlow(),
      AuthStatus.signedIn => const _RiderGate(),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: screen);
  }
}

class _AuthFlow extends ConsumerStatefulWidget {
  const _AuthFlow();

  @override
  ConsumerState<_AuthFlow> createState() => _AuthFlowState();
}

/// Présentation déjà vue sur ce téléphone.
const introSeenKey = 'intro_seen_v1';

class _AuthFlowState extends ConsumerState<_AuthFlow> {
  /// null tant que la mémoire du téléphone n'est pas lue.
  bool? _introSeen;

  @override
  void initState() {
    super.initState();
    ref
        .read(keyValueStoreProvider)
        .read(introSeenKey)
        .then(
          (value) {
            if (mounted) setState(() => _introSeen = value != null);
          },
          // Mémoire illisible : on ne bloque pas l'accès à la connexion.
          onError: (Object _) {
            if (mounted) setState(() => _introSeen = true);
          },
        );
  }

  void _introDone() {
    setState(() => _introSeen = true);
    ref.read(keyValueStoreProvider).write(introSeenKey, '1').ignore();
  }

  OtpChallenge? _challenge;
  String? _phone;

  /// Code juste d'un nouveau compte : il signera les conditions une fois acceptées.
  String? _signupCode;

  @override
  Widget build(BuildContext context) {
    // Premier lancement : courte présentation avant la connexion, une seule fois.
    switch (_introSeen) {
      case null:
        return const SplashScreen();
      case false:
        return RiderIntroScreen(key: const ValueKey('intro'), onDone: _introDone);
      case true:
        break;
    }
    final challenge = _challenge;
    final signupCode = _signupCode;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: challenge != null && signupCode != null
          ? PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) => setState(() => _signupCode = null),
              child: TermsScreen.signup(
                key: const ValueKey('terms'),
                onBack: () => setState(() => _signupCode = null),
                // Le code de connexion signe : la session s'ouvre et RootGate passe au dossier.
                onAccept: (versions) => ref
                    .read(authControllerProvider.notifier)
                    .verifyCode(challengeId: challenge.challengeId, code: signupCode, terms: versions),
              ),
            )
          : challenge == null
          ? SignInScreen(
              key: const ValueKey('sign-in'),
              initialPhone: _phone,
              onCodeSent: (challenge, phone) => setState(() {
                _challenge = challenge;
                _signupCode = null;
                _phone = phone;
              }),
            )
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) => setState(() => _challenge = null),
              child: CodeScreen(
                key: const ValueKey('code'),
                phone: _phone!,
                challenge: challenge,
                onBack: () => setState(() => _challenge = null),
                // La session change d'état : RootGate passe au dossier du livreur.
                onSignedIn: (_) {},
                onTermsRequired: (challenge, code) => setState(() {
                  _challenge = challenge;
                  _signupCode = code;
                }),
              ),
            ),
    );
  }
}

class _RiderGate extends ConsumerStatefulWidget {
  const _RiderGate();

  @override
  ConsumerState<_RiderGate> createState() => _RiderGateState();
}

class _RiderGateState extends ConsumerState<_RiderGate> {
  bool _profileStepDone = false;

  /// « Plus tard » : la nouvelle version sera redemandée pour passer en ligne.
  bool _termsPostponed = false;

  void _reload() {
    ref
      ..invalidate(riderProfileProvider)
      ..invalidate(documentsControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(riderProfileProvider);
    final support = ref.watch(riderConfigProvider).value?.supportPhone;
    void logout() => ref.read(authControllerProvider.notifier).logout();
    void callSupport() {
      if (support != null) launchUrl(Uri(scheme: 'tel', path: support));
    }

    if (profile.isLoading && !profile.hasValue) return const SplashScreen();
    if (profile.hasError && !profile.hasValue) {
      return StatusScreen(
        title: l.genericError,
        body: errorMessage(context, profile.error!),
        actionLabel: l.retry,
        onAction: _reload,
        linkLabel: l.logout,
        onLink: logout,
      );
    }
    // Nouvelle version des conditions : présentée à l'ouverture (sans réseau, plus tard). Une
    // course en cours se termine sans acceptation : « Plus tard » ramène à l'app.
    final terms = ref.watch(termsStatusProvider).value;
    if (terms != null && !terms.upToDate && !_termsPostponed) {
      return TermsScreen.update(onLater: () => setState(() => _termsPostponed = true), onSigned: () {});
    }
    final rider = profile.value;
    if (rider == null) {
      return _profileStepDone
          ? DocumentsScreen(onDone: _reload)
          : ProfileScreen(onDone: () => setState(() => _profileStepDone = true), onBack: logout);
    }
    return switch (rider.status) {
      'ACTIVE' => const HomeFlow(),
      'PENDING' when rider.missingDocuments.isNotEmpty => DocumentsScreen(onDone: _reload),
      'PENDING' => StatusScreen(
        title: l.pendingTitle,
        body: l.pendingBody,
        actionLabel: l.retry,
        onAction: _reload,
        linkLabel: l.logout,
        onLink: logout,
      ),
      _ => StatusScreen(
        title: l.suspendedTitle,
        body: l.suspendedBody,
        actionLabel: support == null ? null : l.callSupport,
        onAction: callSupport,
        linkLabel: l.logout,
        onLink: logout,
      ),
    };
  }
}
