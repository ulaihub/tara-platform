import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_sms/tara_sms.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// 02 · Code reçu par WhatsApp ou SMS : 6 chiffres. Sur Android, le SMS est lu et vérifié
/// sans rien taper ; sur iOS, le clavier propose le code. Renvoi possible à la fin du
/// minuteur fixé par le serveur, et « Recevoir par SMS » quand WhatsApp n'arrive pas.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({
    super.key,
    required this.phone,
    required this.challenge,
    required this.onBack,
    required this.onSignedIn,
    required this.onTermsRequired,
    this.referral,
  });

  final String phone;

  /// Code de parrainage saisi à l'écran précédent, envoyé avec le code SMS.
  final String? referral;
  final OtpChallenge challenge;
  final VoidCallback onBack;
  final void Function(AuthSession session) onSignedIn;

  /// Nouveau compte : les conditions sont à lire et accepter, puis ce même code (juste)
  /// les signe. Reçoit le défi et le code saisi.
  final void Function(OtpChallenge challenge, String code) onTermsRequired;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.challenge;
  late DateTime _resendAt = DateTime.now().add(Duration(seconds: widget.challenge.resendAfterSeconds));
  Timer? _ticker;
  late final SmsCodeReader _reader;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -0.95), size: 280, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 6)),
  ];

  Duration get _remaining {
    final left = _resendAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    // L'erreur reste affichée quand l'app vide les cases (code refusé) ; elle disparaît dès
    // que l'utilisateur retape un chiffre.
    _code.addListener(
      () => setState(() {
        if (_code.text.isNotEmpty) _error = null;
      }),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _reader = ref.read(smsCodeReaderProvider);
    unawaited(_listen());
  }

  /// Android : le code reçu par SMS (WhatsApp en secours compris) est lu puis vérifié.
  Future<void> _listen() async {
    await _reader.cancel();
    final code = await _reader.waitForCode(autoRead: _challenge.autoRead);
    if (!mounted || code == null || _verifying) return;
    _code.text = code;
    unawaited(_verify());
  }

  @override
  void dispose() {
    unawaited(_reader.cancel());
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .verifyCode(challengeId: _challenge.challengeId, code: _code.text, referralCode: widget.referral);
      if (mounted) widget.onSignedIn(session);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'TERMS_REQUIRED') {
        widget.onTermsRequired(_challenge, _code.text);
        return;
      }
      setState(() => _error = errorMessage(context, error));
      _code.clear();
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(context, error));
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Nouveau code ; [channel] SMS quand le code WhatsApp n'est pas arrivé.
  Future<void> _resend({OtpChannel? channel}) async {
    setState(() => _resending = true);
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestCode(digitsOf(widget.phone).substring(3), channel: channel);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _resendAt = DateTime.now().add(Duration(seconds: challenge.resendAfterSeconds));
        _code.clear();
      });
      unawaited(_listen());
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// « +237 6 77 •• •• 56 » : le milieu du numéro est masqué (maquette).
  static String _masked(String phone) {
    final parts = displayPhone(phone).split(RegExp(r'[\s\u00A0\u202F]+'));
    if (parts.length < 4) return displayPhone(phone);
    for (var i = parts.length - 3; i < parts.length - 1; i++) {
      parts[i] = '••';
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final support = ref.watch(appConfigProvider).value?.supportPhone;
    final waiting = _remaining > Duration.zero;
    final whatsapp = _challenge.channel == OtpChannel.whatsapp;
    final link = TaraText.label.copyWith(
      fontWeight: FontWeight.w800,
      color: c.accentText,
      decoration: TextDecoration.underline,
      decorationColor: c.accentText,
    );
    return TaraScreen(
      blobs: _blobs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Maquette : retour 44 et titre Sora 18 sur la même ligne.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.codeTitle, style: TaraText.titlePanel.copyWith(fontSize: 18, color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: whatsapp ? const Color(0xFF25D366) : TaraBrand.orange,
                        ),
                        alignment: Alignment.center,
                        child: whatsapp
                            ? const TaraIcon(TaraIcons.chatBubble, size: 14, filled: true, color: Color(0xFFFFFFFF))
                            : const TaraIcon(TaraIcons.message, size: 13, strokeWidth: 2.2, color: TaraBrand.onBrand),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (whatsapp ? l.codeSentWhatsAppTo : l.codeSentTo)(_masked(widget.phone)),
                          style: TaraText.text.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary.withValues(alpha: .78),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CodeCells(
                    length: 6,
                    controller: _code,
                    oneTimeCode: true,
                    plain: true,
                    cellWidth: 46,
                    cellHeight: 58,
                    digitLabel: l.digitLabel,
                    onCompleted: (_) => _verify(),
                  ),
                  if (_error != null) ...[const SizedBox(height: 14), ErrorLine(_error!)],
                  if (_challenge.autoRead && !_verifying) ...[
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _ReadingGauge(),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            l.codeAutoReading,
                            style: TaraText.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary.withValues(alpha: .74),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    children: [
                      if (whatsapp)
                        _TextLink(
                          label: l.codeBySms,
                          style: link,
                          // Pendant le minuteur, le serveur refuse un nouvel envoi : on dit quand.
                          onPressed: _resending
                              ? null
                              : () => waiting
                                    ? setState(() => _error = l.smsAvailableIn(formatCountdown(_remaining)))
                                    : unawaited(_resend(channel: OtpChannel.sms)),
                        ),
                      if (waiting)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Align(
                            widthFactor: 1,
                            child: Text(
                              l.resendShort(formatCountdown(_remaining)),
                              style: TaraText.label.copyWith(color: c.textPrimary.withValues(alpha: .55)),
                            ),
                          ),
                        )
                      else
                        _TextLink(label: l.resendCode, style: link, onPressed: _resending ? null : _resend),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: l.validate,
                  loading: _verifying,
                  onPressed: _code.text.length == 6 ? _verify : null,
                ),
                if (support != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TaraLink(
                      label: l.noSms,
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: support)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lien texte de la maquette (13, gras, orange), zone touchable de 40 de haut.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.style, required this.onPressed});
  final String label;
  final TextStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Align(
          widthFactor: 1,
          child: Opacity(
            opacity: onPressed == null ? .45 : 1,
            child: Text(label, style: style),
          ),
        ),
      ),
    ),
  );
}

/// Rond de 26 au liquide orange qui ondule : le téléphone guette le code.
class _ReadingGauge extends StatelessWidget {
  const _ReadingGauge();

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color.fromRGBO(255, 177, 92, .45), width: 2),
    ),
    child: const ClipOval(
      child: LiquidFill(
        level: .55,
        front: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
          stops: [0, .18, .5],
        ),
        back: Color.fromRGBO(255, 61, 0, .5),
        frontPeriod: Duration(seconds: 5),
        backPeriod: Duration(seconds: 8),
        amplitude: 2,
      ),
    ),
  );
}
