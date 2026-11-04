import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/client_models.dart';
import '../features/auth/code_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/common/error_text.dart';
import '../features/common/splash_screen.dart';
import '../features/common/status_screen.dart';
import '../features/home/home_screen.dart';
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

class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  OtpChallenge? _challenge;
  String? _phone;
  String? _referral;

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: challenge == null
          ? SignInScreen(
              key: const ValueKey('sign-in'),
              initialPhone: _phone,
              initialReferral: _referral,
              onCodeSent: (challenge, phone, referral) => setState(() {
                _challenge = challenge;
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
              ),
            ),
    );
  }
}

class _AccountGate extends ConsumerWidget {
  const _AccountGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      return WelcomeScreen(me: account, onDone: () => ref.invalidate(meProvider), onLogout: logout);
    }
    return HomeScreen(me: account);
  }
}
