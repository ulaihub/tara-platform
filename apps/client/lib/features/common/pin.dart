import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/models.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import 'error_text.dart';

/// Libellés du code secret, dans la langue de l'app.
PinStrings pinStrings(BuildContext context) {
  final l = AppLocalizations.of(context);
  return PinStrings(
    back: l.back,
    retry: l.retry,
    createTitle: l.pinCreateTitle,
    createBody: l.pinCreateBody,
    confirmTitle: l.pinConfirmTitle,
    mismatch: l.pinMismatch,
    enterTitle: l.pinEnterTitle,
    currentTitle: l.pinCurrentTitle,
    newTitle: l.pinNewTitle,
    forgot: l.pinForgot,
    useBiometrics: l.pinUseBiometrics,
    biometricButton: l.pinBiometricButton,
    biometricTitle: l.pinBiometricTitle,
    cancel: l.cancel,
    deleteDigit: l.pinDelete,
    digitsEntered: l.pinDigitsEntered,
    lockedTitle: l.pinLockedTitle,
    lockedBody: l.pinLockedBody,
    resetBody: l.pinResetBody,
    sendCode: l.pinSendCode,
    codeSentSms: l.pinCodeSentSms,
    codeSentWhatsApp: l.pinCodeSentWhatsApp,
    bySms: l.codeBySms,
    digitLabel: l.digitLabel,
    showBalance: l.balanceShow,
    hideBalance: l.balanceHide,
    errorText: (error) => errorMessage(context, error),
  );
}

/// Code secret, empreinte et lecture du SMS de l'app, pour l'écran du code secret.
PinServices pinServices(BuildContext context, WidgetRef ref) => PinServices(
  api: ref.read(pinApiProvider),
  biometrics: ref.read(biometricsProvider),
  sms: ref.read(smsCodeReaderProvider),
  strings: pinStrings(context),
);

/// Affiche le solde après le code secret (ou l'empreinte), jusqu'au passage en arrière-plan.
Future<void> revealBalance(BuildContext context, WidgetRef ref) async {
  try {
    final shown = await withPin<bool>(
      context,
      pinServices(context, ref),
      reason: AppLocalizations.of(context).pinReasonBalance,
      action: (proof) async {
        await ref.read(pinApiProvider).verify(proof);
        return true;
      },
    );
    if (shown ?? false) ref.read(balanceVisibilityProvider).show();
  } on Exception {
    // Refus inattendu du serveur : le solde reste masqué.
  }
}

/// Solde masqué par défaut (« ••••• F »), avec l'œil pour l'afficher.
class MaskedBalance extends ConsumerWidget {
  const MaskedBalance(this.amount, {super.key, this.style, this.unit = 'F', this.color, this.showEye = true});

  final int amount;
  final TextStyle? style;
  final String unit;
  final Color? color;

  /// Œil à côté du montant (sinon dans l'en-tête de l'écran).
  final bool showEye;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return BalanceAmount(
      amount: amount,
      visibility: ref.watch(balanceVisibilityProvider),
      onReveal: () => revealBalance(context, ref),
      showLabel: l.balanceShow,
      hideLabel: l.balanceHide,
      style: style,
      unit: unit,
      color: color,
      showEye: showEye,
    );
  }
}

/// Profil · Sécurité : code secret (choisir, changer) et empreinte digitale sur ce téléphone.
class SecurityCard extends ConsumerStatefulWidget {
  const SecurityCard({super.key});

  @override
  ConsumerState<SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends ConsumerState<SecurityCard> {
  PinStatus? _status;
  bool _biometricsAvailable = false;
  bool _biometricsOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = ref.read(pinApiProvider);
    try {
      final status = await api.status();
      final available = await ref.read(biometricsProvider).available();
      final on = await api.biometricKey() != null;
      if (!mounted) return;
      setState(() {
        _status = status;
        _biometricsAvailable = available;
        _biometricsOn = on;
      });
    } catch (_) {
      // Sans réseau : la carte reste sur « Code secret », sans état.
    }
  }

  Future<void> _changePin() async {
    await changePin(context, pinServices(context, ref));
    if (mounted) await _load();
  }

  Future<void> _toggleBiometrics(bool on) async {
    final api = ref.read(pinApiProvider);
    setState(() => _busy = true);
    try {
      if (on) {
        // Le code tapé une fois active l'empreinte sur ce téléphone.
        await withPin<bool>(
          context,
          pinServices(context, ref),
          reason: AppLocalizations.of(context).biometricRowBody,
          action: (proof) async {
            await api.enableBiometric(proof.pin ?? '');
            return true;
          },
        );
      } else {
        await api.disableBiometric();
      }
    } on Exception {
      // L'état réel est relu ci-dessous.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final status = _status;
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          ListRow(
            leading: const IconTile(icon: TaraIcons.lock),
            title: l.pinRowTitle,
            subtitle: status == null ? null : (status.set ? l.pinRowSet : l.pinRowNotSet),
            trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
            onTap: () => unawaited(_changePin()),
          ),
          if (_biometricsAvailable && (status?.set ?? false))
            ListRow(
              leading: const IconTile(icon: TaraIcons.fingerprint),
              title: l.biometricRowTitle,
              subtitle: l.biometricRowBody,
              trailing: GlassSwitch(
                value: _biometricsOn,
                semanticLabel: l.biometricRowTitle,
                onChanged: _busy ? null : (value) => unawaited(_toggleBiometrics(value)),
              ),
            ),
        ],
      ),
    );
  }
}
