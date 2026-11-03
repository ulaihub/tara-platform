import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/api_exception.dart';
import '../core/api/models.dart';
import '../features/auth/code_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/common/error_text.dart';
import '../features/common/splash_screen.dart';
import '../features/common/status_screen.dart';
import '../features/home/home_flow.dart';
import '../features/onboarding/documents_controller.dart';
import '../features/onboarding/documents_screen.dart';
import '../features/onboarding/profile_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

/// Dossier livreur du compte connecté ; null s'il n'a pas encore postulé.
final riderProfileProvider = FutureProvider<RiderProfile?>((ref) async {
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

class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  OtpChallenge? _challenge;
  String? _phone;

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: challenge == null
          ? SignInScreen(
              key: const ValueKey('sign-in'),
              initialPhone: _phone,
              onCodeSent: (challenge, phone) => setState(() {
                _challenge = challenge;
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
