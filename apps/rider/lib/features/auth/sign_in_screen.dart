import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/brand.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/city_3d.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      // Le quartier en relief de la maquette, avec un itinéraire orange, derrière le logo.
      background: Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 330 * width / 390,
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const City3D(blocks: cityOffer, top: -20, height: 330, overlay: _route),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: .25), c.bg.withValues(alpha: .1), c.bg],
                    stops: const [0, .5, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ScrollWithFooter(
        horizontal: 24,
        top: 16,
        content: [
          const Align(alignment: Alignment.centerLeft, child: TaraLogo(width: 120)),
          SizedBox(height: (width * 330 / 390 - 150).clamp(60.0, 220.0)),
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

/// Itinéraire orange dessiné sur les rues du quartier de la page de connexion.
void _route(Canvas canvas, Offset Function(double x, double y) ground) {
  const points = [
    Offset(30, 128),
    Offset(138, 128),
    Offset(138, 256),
    Offset(276, 256),
    Offset(276, 128),
    Offset(340, 128),
  ];
  final path = Path();
  for (final (i, p) in points.indexed) {
    final at = ground(p.dx, p.dy);
    i == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
  }
  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas
    ..drawPath(path, stroke(const Color.fromRGBO(255, 106, 0, .28), 10))
    ..drawPath(path, stroke(TaraBrand.orange, 3.6));
}
