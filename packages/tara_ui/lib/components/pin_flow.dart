import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/models.dart';
import 'package:tara_core/api/pin_api.dart';
import 'package:tara_core/security/biometrics.dart';
import 'package:tara_sms/tara_sms.dart';

import '../format.dart';
import '../motion/liquid_background.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'buttons.dart';
import 'check_row.dart';
import 'inputs.dart';
import 'layout.dart';

/// Longueur du code secret : 4 chiffres, comme Orange Money.
const pinLength = 4;

/// Libellés du code secret, traduits par chaque app.
class PinStrings {
  const PinStrings({
    required this.back,
    required this.retry,
    required this.createTitle,
    required this.createBody,
    required this.confirmTitle,
    required this.mismatch,
    required this.enterTitle,
    required this.currentTitle,
    required this.newTitle,
    required this.forgot,
    required this.useBiometrics,
    required this.biometricButton,
    required this.biometricTitle,
    required this.cancel,
    required this.deleteDigit,
    required this.digitsEntered,
    required this.lockedTitle,
    required this.lockedBody,
    required this.resetBody,
    required this.sendCode,
    required this.codeSentSms,
    required this.codeSentWhatsApp,
    required this.bySms,
    required this.digitLabel,
    required this.showBalance,
    required this.hideBalance,
    required this.errorText,
  });

  final String back;
  final String retry;
  final String createTitle;

  /// « 4 chiffres, comme pour Orange Money… Ne le donnez à personne, même à Tara. »
  final String createBody;
  final String confirmTitle;
  final String mismatch;
  final String enterTitle;
  final String currentTitle;
  final String newTitle;
  final String forgot;
  final String useBiometrics;
  final String biometricButton;
  final String biometricTitle;
  final String cancel;
  final String deleteDigit;

  /// « 2 chiffres sur 4 » (lecteur d'écran).
  final String Function(int count) digitsEntered;
  final String lockedTitle;
  final String lockedBody;
  final String resetBody;
  final String sendCode;
  final String codeSentSms;
  final String codeSentWhatsApp;
  final String bySms;
  final String Function(int index) digitLabel;
  final String showBalance;
  final String hideBalance;

  /// Message d'une erreur (celui du serveur, ou réseau).
  final String Function(Object error) errorText;
}

/// Ce dont l'écran du code secret a besoin, fourni par chaque app.
class PinServices {
  const PinServices({required this.api, required this.biometrics, required this.sms, required this.strings});

  final PinApi api;
  final Biometrics biometrics;
  final SmsCodeReader sms;
  final PinStrings strings;
}

/// Erreurs propres au code secret, traitées sur son écran ; les autres reviennent à l'appelant.
const _pinErrors = {'PIN_INVALID', 'PIN_LOCKED', 'PIN_NOT_SET', 'PIN_REQUIRED', 'BIOMETRIC_INVALID'};

/// Issue de l'écran : le résultat de l'action, ou l'erreur qu'elle a levée.
class _Outcome<T> {
  const _Outcome.value(T this.value) : error = null;
  const _Outcome.error(Object this.error) : value = null;
  final T? value;
  final Object? error;
}

/// Ouvre l'écran du code secret puis lance [action] avec la preuve (code tapé ou empreinte) :
/// création du code s'il n'existe pas, empreinte si elle est activée sur ce téléphone, code
/// oublié ou bloqué par un code reçu. Renvoie le résultat de [action], ou null si la personne
/// renonce ; une autre erreur que celles du code (réseau, refus) est relancée à l'appelant.
/// [reason] dit ce que le code confirme (« Pour retirer 5 000 F »).
Future<T?> withPin<T>(
  BuildContext context,
  PinServices services, {
  required String reason,
  required Future<T> Function(PinProof proof) action,
}) async {
  final outcome = await Navigator.of(context).push<_Outcome<T>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinScreen<T>(services: services, reason: reason, action: action),
    ),
  );
  if (outcome == null) return null;
  if (outcome.error case final error?) throw error;
  return outcome.value;
}

/// Profil : choisir ou changer le code secret. Renvoie true une fois enregistré.
Future<bool> changePin(BuildContext context, PinServices services) async {
  final outcome = await Navigator.of(context).push<_Outcome<bool>>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => PinScreen<bool>(services: services, change: true)),
  );
  return outcome?.value ?? false;
}

enum _Step { loading, failed, create, confirm, enter, current, newPin, confirmNew, locked, resetCode }

/// Pavé du code secret : création (deux fois), saisie, changement, code oublié ou bloqué.
class PinScreen<T> extends StatefulWidget {
  const PinScreen({super.key, required this.services, this.reason, this.action, this.change = false})
    : assert(change || action != null);

  final PinServices services;
  final String? reason;
  final Future<T> Function(PinProof proof)? action;

  /// Profil : changer le code (ou le choisir), sans autre action.
  final bool change;

  @override
  State<PinScreen<T>> createState() => _PinScreenState<T>();
}

class _PinScreenState<T> extends State<PinScreen<T>> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  _Step _step = _Step.loading;
  String _digits = '';
  String? _first;
  String? _current;
  String? _error;
  bool _busy = false;
  bool _biometricsAvailable = false;
  bool _useBiometrics = true;
  String? _biometricKey;

  // Code oublié : code reçu, puis nouveau code (deux fois).
  final _resetCode = TextEditingController();
  OtpChallenge? _challenge;
  String? _challengeCode;

  PinStrings get _s => widget.services.strings;
  PinApi get _api => widget.services.api;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(widget.services.sms.cancel());
    _resetCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _step = _Step.loading;
      _error = null;
    });
    try {
      final status = await _api.status();
      _biometricsAvailable = await widget.services.biometrics.available();
      _biometricKey = await _api.biometricKey();
      if (!mounted) return;
      setState(() {
        _step = !status.set
            ? _Step.create
            : status.locked
            ? _Step.locked
            : widget.change
            ? _Step.current
            : _Step.enter;
      });
      if (_step == _Step.enter) unawaited(_tryBiometrics());
    } catch (error) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _error = _s.errorText(error);
        });
      }
    }
  }

  bool get _canUseBiometrics => !widget.change && _biometricsAvailable && _biometricKey != null;

  Future<void> _tryBiometrics() async {
    final key = _biometricKey;
    if (!_canUseBiometrics || key == null || _busy) return;
    final ok = await widget.services.biometrics.confirm(
      BiometricPrompt(reason: widget.reason ?? _s.enterTitle, title: _s.biometricTitle, cancel: _s.cancel),
    );
    if (ok && mounted) await _run(PinProof.biometric(key));
  }

  /// Lance l'action avec la preuve ; les refus du code restent sur cet écran.
  Future<void> _run(PinProof proof) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.action!(proof);
      if (mounted) Navigator.of(context).pop(_Outcome<T>.value(result));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!_pinErrors.contains(error.code)) {
        Navigator.of(context).pop(_Outcome<T>.error(error));
        return;
      }
      if (error.code == 'BIOMETRIC_INVALID') {
        await _api.forgetBiometric();
        _biometricKey = null;
      }
      setState(() {
        _digits = '';
        switch (error.code) {
          case 'PIN_LOCKED':
            _step = _Step.locked;
          case 'PIN_NOT_SET':
            _step = _Step.create;
          default:
            _step = _Step.enter;
            _error = _s.errorText(error);
        }
      });
      if (error.code == 'PIN_INVALID') unawaited(HapticFeedback.heavyImpact());
    } catch (error) {
      // Réseau : le message reste ici, la personne réessaie en tapant de nouveau son code.
      if (mounted) {
        setState(() {
          _digits = '';
          _step = _Step.enter;
          _error = _s.errorText(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _press(String digit) {
    if (_busy || _digits.length >= pinLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length == pinLength) unawaited(_complete(_digits));
  }

  void _erase() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _restart(_Step step, {String? error}) => setState(() {
    _step = step;
    _digits = '';
    _first = null;
    _error = error;
  });

  Future<void> _complete(String pin) async {
    switch (_step) {
      case _Step.enter:
        await _run(PinProof.pin(pin));
      case _Step.create || _Step.newPin:
        setState(() {
          _first = pin;
          _digits = '';
          _step = _step == _Step.create ? _Step.confirm : _Step.confirmNew;
        });
      case _Step.current:
        setState(() {
          _current = pin;
          _digits = '';
          _step = _Step.newPin;
        });
      case _Step.confirm || _Step.confirmNew:
        if (pin != _first) {
          _restart(_step == _Step.confirm ? _Step.create : _Step.newPin, error: _s.mismatch);
          return;
        }
        await _save(pin);
      default:
        break;
    }
  }

  /// Enregistre le code : premier, changement (code actuel) ou oubli (code reçu).
  Future<void> _save(String pin) async {
    final fromReset = _challengeCode != null;
    setState(() => _busy = true);
    try {
      await _api.set(
        pin,
        currentPin: fromReset ? null : _current,
        challengeId: fromReset ? _challenge?.challengeId : null,
        code: _challengeCode,
      );
      if (_biometricsAvailable && _useBiometrics) {
        try {
          await _api.enableBiometric(pin);
        } catch (_) {
          // L'empreinte pourra être activée plus tard depuis le profil.
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (error.code) {
        case 'PIN_INVALID' || 'PIN_REQUIRED':
          _restart(_Step.current, error: _s.errorText(error));
        case 'PIN_LOCKED':
          _restart(_Step.locked);
        case 'OTP_INVALID' || 'OTP_EXPIRED' || 'OTP_TOO_MANY_ATTEMPTS':
          _resetCode.clear();
          _challengeCode = null;
          if (error.code != 'OTP_INVALID') _challenge = null;
          _restart(_Step.resetCode, error: _s.errorText(error));
        default:
          _restart(
            fromReset ? _Step.newPin : (_current == null ? _Step.create : _Step.newPin),
            error: _s.errorText(error),
          );
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _restart(_step == _Step.confirm ? _Step.create : _Step.newPin, error: _s.errorText(error));
      }
      return;
    }
    if (!mounted) return;
    if (widget.change) {
      Navigator.of(context).pop(_Outcome<T>.value(true as T));
      return;
    }
    await _run(PinProof.pin(pin));
  }

  // --- Code oublié ou bloqué ---------------------------------------------------------------

  void _forgot() => setState(() {
    _step = _Step.resetCode;
    _digits = '';
    _error = null;
  });

  Future<void> _sendResetCode({OtpChannel? channel}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sms = widget.services.sms;
      final challenge = await _api.requestResetCode(appHash: await sms.appHash(), channel: channel);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _step = _Step.resetCode;
        _resetCode.clear();
      });
      unawaited(sms.cancel().then((_) => sms.waitForCode(autoRead: challenge.autoRead)).then(_received));
    } catch (error) {
      if (mounted) setState(() => _error = _s.errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _received(String? code) {
    if (!mounted || code == null || _step != _Step.resetCode || _challenge == null) return;
    _resetCode.text = code;
    _useResetCode(code);
  }

  void _useResetCode(String code) => setState(() {
    _challengeCode = code;
    _current = null;
    _step = _Step.newPin;
    _digits = '';
    _error = null;
  });

  // --- Affichage ---------------------------------------------------------------------------

  String get _title => switch (_step) {
    _Step.create => _s.createTitle,
    _Step.confirm || _Step.confirmNew => _s.confirmTitle,
    _Step.current => _s.currentTitle,
    _Step.newPin => _s.newTitle,
    _Step.locked => _s.lockedTitle,
    _Step.resetCode => _s.newTitle,
    _ => _s.enterTitle,
  };

  String? get _body => switch (_step) {
    _Step.create || _Step.newPin => _s.createBody,
    _Step.enter => widget.reason,
    _Step.locked => _s.lockedBody,
    _Step.resetCode =>
      _challenge == null
          ? _s.resetBody
          : (_challenge!.channel == OtpChannel.whatsapp ? _s.codeSentWhatsApp : _s.codeSentSms),
    _ => null,
  };

  bool get _showsPad => switch (_step) {
    _Step.create || _Step.confirm || _Step.enter || _Step.current || _Step.newPin || _Step.confirmNew => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final body = _body;
    // Petits téléphones et texte agrandi : l'écran défile plutôt que de déborder.
    return TaraScreen(
      blobs: _blobs,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: IntrinsicHeight(child: _layout(c, body)),
          ),
        ),
      ),
    );
  }

  Widget _layout(TaraColors c, String? body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: GlassIconButton(
          icon: TaraIcons.close,
          label: _s.back,
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      const SizedBox(height: 20),
      Center(child: TaraIcon(TaraIcons.lock, size: 30, color: c.accentText)),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: Text(
          _title,
          textAlign: TextAlign.center,
          style: TaraText.titleForm.copyWith(color: c.textPrimary),
        ),
      ),
      if (body != null) ...[
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TaraText.body.copyWith(color: c.textSecondary),
        ),
      ],
      const SizedBox(height: 22),
      if (_step == _Step.loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_showsPad)
        Expanded(child: _padArea(c))
      else
        Expanded(child: _otherArea(c)),
    ],
  );

  Widget _padArea(TaraColors c) => Column(
    children: [
      PinDots(filled: _digits.length, label: _s.digitsEntered(_digits.length)),
      const SizedBox(height: 14),
      SizedBox(
        height: 44,
        child: _error == null
            ? (_busy ? const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator())) : null)
            : Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TaraText.label.copyWith(color: c.dangerText),
                ),
              ),
      ),
      if ((_step == _Step.confirm || _step == _Step.confirmNew) && _biometricsAvailable)
        TaraCheckRow(
          value: _useBiometrics,
          onChanged: _busy ? null : (value) => setState(() => _useBiometrics = value),
          label: TextSpan(text: _s.useBiometrics),
        ),
      const Spacer(),
      PinKeypad(
        onDigit: _press,
        onErase: _erase,
        onBiometric: _step == _Step.enter && _canUseBiometrics ? () => unawaited(_tryBiometrics()) : null,
        biometricLabel: _s.biometricButton,
        eraseLabel: _s.deleteDigit,
      ),
      const SizedBox(height: 10),
      if (_step == _Step.enter || _step == _Step.current)
        TaraLink(label: _s.forgot, onPressed: _busy ? null : _forgot)
      else
        const SizedBox(height: 24),
    ],
  );

  Widget _otherArea(TaraColors c) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == _Step.resetCode && _challenge != null) ...[
          CodeCells(
            length: 6,
            controller: _resetCode,
            oneTimeCode: true,
            cellHeight: 56,
            digitLabel: _s.digitLabel,
            onCompleted: _useResetCode,
          ),
          if (_challenge!.channel == OtpChannel.whatsapp) ...[
            const SizedBox(height: 12),
            Center(
              child: TaraLink(
                label: _s.bySms,
                onPressed: _busy ? null : () => unawaited(_sendResetCode(channel: OtpChannel.sms)),
              ),
            ),
          ],
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TaraText.label.copyWith(color: c.dangerText),
            ),
          ),
        ],
        const Spacer(),
        if (_step == _Step.failed)
          PrimaryButton(label: _s.retry, onPressed: () => unawaited(_load()))
        else if (_challenge == null)
          PrimaryButton(
            label: _s.sendCode,
            icon: TaraIcons.message,
            loading: _busy,
            onPressed: () => unawaited(_sendResetCode()),
          ),
      ],
    );
  }
}

/// Points du code : pleins pour les chiffres tapés (jamais les chiffres eux-mêmes).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, required this.label, this.length = pinLength});

  final int filled;
  final int length;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? c.accentText : Colors.transparent,
                border: Border.all(color: i < filled ? c.accentText : c.textTertiary, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pavé numérique du code secret (comme celui de MoMo) : 1 à 9, empreinte, 0, effacer.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onErase,
    required this.eraseLabel,
    required this.biometricLabel,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final VoidCallback? onBiometric;
  final String eraseLabel;
  final String biometricLabel;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    Widget digit(String value) => _KeyButton(
      label: value,
      onPressed: () => onDigit(value),
      child: Text(value, style: TaraText.amountL.copyWith(color: c.textPrimary, fontSize: 28)),
    );
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final value in row) digit(value)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (onBiometric case final biometric?)
              _KeyButton(
                label: biometricLabel,
                onPressed: biometric,
                child: TaraIcon(TaraIcons.fingerprint, size: 30, color: c.accentText),
              )
            else
              SizedBox.square(dimension: _KeyButton.sizeFor(context)),
            digit('0'),
            _KeyButton(
              label: eraseLabel,
              onPressed: onErase,
              child: TaraIcon(TaraIcons.backspace, size: 26, color: c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onPressed, required this.child});

  static const size = 72.0;

  /// Touches plus petites sur les écrans de moins de 700 px de haut.
  static double sizeFor(BuildContext context) => MediaQuery.sizeOf(context).height < 700 ? 60 : size;

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final dimension = sizeFor(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dimension < size ? 3 : 5),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: c.glass,
          shape: CircleBorder(side: BorderSide(color: c.glassBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Solde masqué -----------------------------------------------------------------------------

/// Solde masqué par défaut, comme sur l'app MoMo : affiché après le code secret (ou
/// l'empreinte), masqué de nouveau quand l'app passe en arrière-plan.
class BalanceVisibility extends ChangeNotifier {
  BalanceVisibility() {
    _listener = AppLifecycleListener(onHide: hide);
  }

  late final AppLifecycleListener _listener;
  bool _visible = false;

  bool get visible => _visible;

  void show() {
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }
}

/// Montant d'un solde : masqué (« ••••• F ») tant que le code n'a pas été donné, avec l'œil
/// pour l'afficher ou le masquer. [onReveal] demande le code puis appelle `show()`.
class BalanceAmount extends StatelessWidget {
  const BalanceAmount({
    super.key,
    required this.amount,
    required this.visibility,
    required this.onReveal,
    required this.showLabel,
    required this.hideLabel,
    this.style,
    this.unit = 'F',
    this.color,
    this.showEye = true,
  });

  final int amount;

  /// Œil à côté du montant ; absent quand un bouton œil est posé ailleurs (en-tête).
  final bool showEye;
  final BalanceVisibility visibility;
  final VoidCallback onReveal;
  final String showLabel;
  final String hideLabel;
  final TextStyle? style;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return ListenableBuilder(
      listenable: visibility,
      builder: (context, _) {
        final visible = visibility.visible;
        final main = (style ?? TaraText.amountL).copyWith(color: color ?? c.textPrimary);
        // Toute la ligne (montant et œil) se touche pour afficher ou masquer le solde.
        return Semantics(
          button: true,
          label: visible ? hideLabel : showLabel,
          child: InkWell(
            onTap: visible ? visibility.hide : onReveal,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ExcludeSemantics(
                    excluding: !visible,
                    child: visible
                        ? AmountText(amount, unit: unit, style: style, color: color)
                        : Text.rich(
                            TextSpan(
                              children: [
                                // Police du texte courant : celle des montants n'a pas le point « • ».
                                TextSpan(
                                  text: '•••••',
                                  style: TaraText.bodyStrong.copyWith(
                                    fontSize: main.fontSize,
                                    color: main.color,
                                    letterSpacing: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: ' $unit',
                                  style: TaraText.unit.copyWith(color: color?.withValues(alpha: .72) ?? c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                if (showEye)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TaraIcon(
                      visible ? TaraIcons.eyeOff : TaraIcons.eye,
                      size: 22,
                      color: color?.withValues(alpha: .72) ?? c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Texte d'un solde dans une phrase : le montant, ou « ••••• F » s'il est masqué.
String balanceText(BalanceVisibility visibility, int amount) =>
    visibility.visible ? '${formatAmount(amount)} F' : '••••• F';
