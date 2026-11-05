import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/brand.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../legal/terms_screen.dart';

/// 01 · Connexion par SMS.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.onCodeSent, this.initialPhone});

  final void Function(OtpChallenge challenge, String phone) onCodeSent;
  final String? initialPhone;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _phone = TextEditingController(text: widget.initialPhone == null ? '' : _grouped(widget.initialPhone!));
  bool _sending = false;
  String? _error;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.0), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(
      alignment: Alignment(-1.35, 0.05),
      size: 230,
      colors: BlobSpec.warm,
      blur: 64,
      delay: Duration(seconds: 4),
    ),
    BlobSpec(alignment: Alignment(1.2, 1.05), size: 260, colors: BlobSpec.soft, blur: 70, delay: Duration(seconds: 8)),
  ];

  static String _grouped(String phone) => PhoneInputFormatter()
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: digitsOf(phone).replaceFirst(RegExp('^237'), '')),
      )
      .text;

  String get _digits => digitsOf(_phone.text);

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isCameroonMobile(_digits)) {
      setState(() => _error = AppLocalizations.of(context).phoneInvalid);
      return;
    }
    setState(() => _sending = true);
    try {
      final challenge = await ref.read(authControllerProvider.notifier).requestCode(_digits);
      if (mounted) widget.onCodeSent(challenge, '+237$_digits');
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final config = ref.watch(riderConfigProvider).value;
    final dialCode = config?.dialCode ?? '+237';
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 24,
        top: 16,
        content: [
          const SizedBox(height: 12),
          const Center(child: TaraLogo(width: 214)),
          const SizedBox(height: 28),
          Text(l.riderSpace, style: TaraText.overlineLarge.copyWith(color: c.accentText)),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(l.signInTitle, style: TaraText.titleAccess.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 10),
          Text(l.signInBody, style: TaraText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 24),
          GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaraTextField(
                  label: l.phoneLabel,
                  hint: l.phoneHint,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [PhoneInputFormatter()],
                  onSubmitted: (_) => _submit(),
                  leading: PhonePrefixButton(prefix: dialCode, semanticLabel: l.countryCodeLabel(dialCode)),
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[ErrorLine(_error!), const SizedBox(height: 10)],
                Text(l.phoneHelp, style: TaraText.small.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            PrimaryButton(
              label: l.getCode,
              icon: TaraIcons.arrowRight,
              loading: _sending,
              onPressed: _digits.length == 9 ? _submit : null,
            ),
            const SizedBox(height: 14),
            _Legal(
              style: TaraText.small.copyWith(color: c.textTertiary),
              link: c.accentText,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legal extends StatefulWidget {
  const _Legal({required this.style, required this.link});
  final TextStyle style;
  final Color link;

  @override
  State<_Legal> createState() => _LegalState();
}

/// Liens vers les textes complets, lus dans l'app (ils sont acceptés à l'étape suivante
/// pour un nouveau compte).
class _LegalState extends State<_Legal> {
  late final _terms = TapGestureRecognizer()..onTap = () => _open('livreurs');
  late final _privacy = TapGestureRecognizer()..onTap = () => _open(LegalApi.privacyDocument);

  void _open(String document) =>
      unawaited(Navigator.of(context).push(scopedPage<void>(context, (_) => LegalTextScreen(document: document))));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final linkStyle = widget.style.copyWith(color: widget.link, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: l.legalPrefix),
          TextSpan(text: l.terms, style: linkStyle, recognizer: _terms),
          TextSpan(text: l.legalAnd),
          TextSpan(text: l.privacy, style: linkStyle, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
