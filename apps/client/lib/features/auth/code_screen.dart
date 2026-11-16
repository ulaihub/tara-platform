import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_sms/tara_sms.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final support = ref.watch(appConfigProvider).value?.supportPhone;
    final waiting = _remaining > Duration.zero;
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Align(
            alignment: Alignment.centerLeft,
            child: GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(l.codeTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${(_challenge.channel == OtpChannel.whatsapp ? l.codeSentWhatsAppTo : l.codeSentTo)(displayPhone(widget.phone))} · ',
                style: TaraText.body.copyWith(color: c.textSecondary),
              ),
              TaraLink(label: l.change, onPressed: widget.onBack),
            ],
          ),
          const SizedBox(height: 24),
          CodeCells(
            length: 6,
            controller: _code,
            oneTimeCode: true,
            digitLabel: l.digitLabel,
            onCompleted: (_) => _verify(),
          ),
          if (_error != null) ...[const SizedBox(height: 14), ErrorLine(_error!)],
          const SizedBox(height: 20),
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                TaraIcon(TaraIcons.timer, size: 20, color: c.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    waiting ? l.resendIn(formatCountdown(_remaining)) : l.resendNow,
                    style: TaraText.text.copyWith(color: c.textSecondary),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: GlassButton(
                    label: l.resend,
                    height: 48,
                    radius: 14,
                    onPressed: waiting || _resending ? null : _resend,
                  ),
                ),
              ],
            ),
          ),
          if (_challenge.channel == OtpChannel.whatsapp) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(
                label: l.codeBySms,
                onPressed: waiting || _resending ? null : () => unawaited(_resend(channel: OtpChannel.sms)),
              ),
            ),
          ],
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            PrimaryButton(label: l.validate, loading: _verifying, onPressed: _code.text.length == 6 ? _verify : null),
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
    );
  }
}
