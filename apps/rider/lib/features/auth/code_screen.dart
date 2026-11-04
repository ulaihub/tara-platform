import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../core/api/models.dart';
import '../../core/env.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/phone_format.dart';

/// 02 · Code SMS : 6 chiffres, remplissage automatique proposé par le système, renvoi
/// possible à la fin du minuteur fixé par le serveur.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({
    super.key,
    required this.phone,
    required this.challenge,
    required this.onBack,
    required this.onSignedIn,
  });

  final String phone;
  final OtpChallenge challenge;
  final VoidCallback onBack;
  final void Function(AuthSession session) onSignedIn;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.challenge;
  late DateTime _resendAt = DateTime.now().add(Duration(seconds: widget.challenge.resendAfterSeconds));
  Timer? _ticker;
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
    _code.addListener(() => setState(() => _error = null));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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
          .verifyCode(challengeId: _challenge.challengeId, code: _code.text, termsVersion: Env.termsVersion);
      if (mounted) widget.onSignedIn(session);
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(context, error));
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestCode(digitsOf(widget.phone).substring(3));
      setState(() {
        _challenge = challenge;
        _resendAt = DateTime.now().add(Duration(seconds: challenge.resendAfterSeconds));
        _code.clear();
      });
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
    final support = ref.watch(riderConfigProvider).value?.supportPhone;
    final waiting = _remaining > Duration.zero;
    return TaraScreen(
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
                '${l.codeSentTo(displayPhone(widget.phone))} · ',
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
