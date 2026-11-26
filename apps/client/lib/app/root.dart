import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/client_models.dart';
import '../features/auth/code_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/common/error_text.dart';
import '../features/common/splash_screen.dart';
import '../features/common/status_screen.dart';
import '../features/home/home_flow.dart';
import '../features/legal/terms_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

/// Aiguillage selon la session et le compte : connexion, bienvenue (première connexion),
/// accueil.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final Widget screen = switch (auth.value) {
      null => const SplashScreen(),
      AuthStatus.signedOut => const _AuthFlow(),
      AuthStatus.signedIn => const _AccountGate(),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: screen);
  }
}

class _AuthFlow extends ConsumerStatefulWidget {
  const _AuthFlow();

  @override
  ConsumerState<_AuthFlow> createState() => _AuthFlowState();
}

/// Présentation déjà vue sur ce téléphone (clé gardée dans le stockage de l'app).
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
  String? _referral;

  /// Code juste d'un nouveau compte : il signera les conditions une fois acceptées.
  String? _signupCode;

  @override
  Widget build(BuildContext context) {
    // Premier lancement : présentation (maquettes) avant la connexion, une seule fois.
    switch (_introSeen) {
      case null:
        return const SplashScreen();
      case false:
        return ClientIntroScreen(key: const ValueKey('intro'), onDone: _introDone);
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
                // Le code de connexion signe : la session s'ouvre et RootGate passe au compte.
                onAccept: (versions) => ref
                    .read(authControllerProvider.notifier)
                    .verifyCode(
                      challengeId: challenge.challengeId,
                      code: signupCode,
                      terms: versions,
                      referralCode: _referral,
                    ),
              ),
            )
          : challenge == null
          ? SignInScreen(
              key: const ValueKey('sign-in'),
              initialPhone: _phone,
              initialReferral: _referral,
              onCodeSent: (challenge, phone, referral) => setState(() {
                _challenge = challenge;
                _signupCode = null;
                _phone = phone;
                _referral = referral;
              }),
            )
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) => setState(() => _challenge = null),
              child: CodeScreen(
                key: const ValueKey('code'),
                phone: _phone!,
                challenge: challenge,
                referral: _referral,
                onBack: () => setState(() => _challenge = null),
                // La session change d'état : RootGate passe au compte.
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

class _AccountGate extends ConsumerStatefulWidget {
  const _AccountGate();

  @override
  ConsumerState<_AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<_AccountGate> {
  /// « Plus tard » : la nouvelle version sera redemandée avant la prochaine commande.
  bool _termsPostponed = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    void logout() => ref.read(authControllerProvider.notifier).logout();
    if (me.isLoading && !me.hasValue) return const SplashScreen();
    if (me.hasError && !me.hasValue) {
      return StatusScreen(
        title: l.genericError,
        body: errorMessage(context, me.error!),
        actionLabel: l.retry,
        onAction: () => ref.invalidate(meProvider),
        linkLabel: l.logout,
        onLink: logout,
      );
    }
    final account = me.value!;
    if (account.needsProfile) {
      return WelcomeScreen(me: account, onDone: () => ref.invalidate(meProvider));
    }
    // Nouvelle version des conditions : présentée à l'ouverture (sans réseau, plus tard).
    final terms = ref.watch(termsStatusProvider).value;
    if (terms != null && !terms.upToDate && !_termsPostponed) {
      return TermsScreen.update(onLater: () => setState(() => _termsPostponed = true), onSigned: () {});
    }
    return HomeFlow(me: account);
  }
}
