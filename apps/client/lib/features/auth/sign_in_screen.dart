import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/brand.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../legal/terms_screen.dart';

/// 01 · Connexion par SMS ; un code de parrainage (C6) peut être saisi pour un nouveau
/// compte.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.onCodeSent, this.initialPhone, this.initialReferral});

  /// Code envoyé : numéro au format +237… et code de parrainage saisi (ou null).
  final void Function(OtpChallenge challenge, String phone, String? referral) onCodeSent;
  final String? initialPhone;
  final String? initialReferral;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _phone = TextEditingController(text: widget.initialPhone == null ? '' : _grouped(widget.initialPhone!));
  late final _referral = TextEditingController(text: widget.initialReferral ?? '');
  late bool _withReferral = (widget.initialReferral ?? '').isNotEmpty;
  bool _sending = false;
  String? _error;

  // Maquette : halos flous (320 à -110,-60 ; 280 à 200,260 ; 260 à -60,620).
  static const _blobs = [
    BlobSpec(alignment: Alignment(-.74, -.76), size: 320, colors: BlobSpec.soft, blur: 46, opacity: .45 / .5),
    BlobSpec(alignment: Alignment(.74, -.05), size: 280, colors: BlobSpec.warm, blur: 46, opacity: .22 / .5),
    BlobSpec(alignment: Alignment(-.64, .78), size: 260, colors: BlobSpec.soft, blur: 46, opacity: .3 / .5),
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
    _referral.dispose();
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
      final referral = _referral.text.trim().toUpperCase();
      if (mounted) widget.onCodeSent(challenge, '+237$_digits', _withReferral && referral.isNotEmpty ? referral : null);
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
    final config = ref.watch(appConfigProvider).value;
    final dialCode = config?.dialCode ?? '+237';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Maquette : colis Tara en 3D de 130 qui tourne (12 s) et flotte, logo en haut à gauche.
        SizedBox(
          height: 330,
          child: Stack(
            children: [
              const Center(
                child: Parcel3D(size: 130, label: 'n° 1', period: Duration(seconds: 12)),
              ),
              Positioned(
                left: 20,
                top: 22,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF16120E), borderRadius: BorderRadius.circular(14)),
                  child: const SizedBox(
                    width: 52,
                    height: 36,
                    child: Center(child: TaraLogo(width: 52, ink: Color(0xFFFFFFFF))),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.signInTitle, style: TaraText.titleAccess.copyWith(color: c.textPrimary, height: 1.12)),
                ),
                const SizedBox(height: 14),
                Text(l.signInBody, style: TaraText.body.copyWith(color: c.textPrimary.withValues(alpha: .74))),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: BoxedField(
                        label: l.countryLabel,
                        value: dialCode,
                        valueLeading: const CameroonFlag(width: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BoxedField(
                        label: l.phoneLabel,
                        hint: l.phoneHint,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumberNational],
                        inputFormatters: [PhoneInputFormatter()],
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
                const SizedBox(height: 12),
                if (_withReferral)
                  BoxedField(
                    label: l.referralLabel,
                    hint: l.referralHint,
                    controller: _referral,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TaraLink(label: l.haveReferral, onPressed: () => setState(() => _withReferral = true)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: l.getCode, loading: _sending, onPressed: _digits.length == 9 ? _submit : null),
          const SizedBox(height: 10),
          _Legal(
            style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .62), height: 1.5),
            link: c.accentText,
          ),
        ],
      ),
    );
    return TaraScreen(
      blobs: _blobs,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [content, const Spacer(), footer],
              ),
            ),
          ),
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
  late final _terms = TapGestureRecognizer()..onTap = () => _open('expediteurs');
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
    final linkStyle = widget.style.copyWith(
      color: widget.link,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: widget.link,
    );
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
