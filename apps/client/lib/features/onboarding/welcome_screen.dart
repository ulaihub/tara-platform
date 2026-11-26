import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/operator_logo.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

enum _Kind { person, shop }

/// 03 · Bienvenue (maquette « Client-Bienvenue ») : le nom, qui figure dans les messages aux
/// destinataires ; pour une boutique (A2), son nom et le numéro Mobile Money des reversements.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.me, required this.onDone});

  final Me me;
  final VoidCallback onDone;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.8), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  /// Nom de la personne, ou de la boutique : il figure dans les messages aux destinataires.
  final _name = TextEditingController();
  late final _payout = TextEditingController(text: _national(widget.me.phone));
  _Kind _kind = _Kind.person;

  /// Le numéro des reversements s'affiche masqué ; touché, il devient modifiable.
  bool _editPayout = false;
  bool _tried = false;
  bool _saving = false;
  String? _error;

  static String _national(String phone) {
    final digits = digitsOf(phone).replaceFirst(RegExp('^237'), '');
    return PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
  }

  /// « 6 77 •• •• 56 ».
  static String _masked(String national) {
    final parts = national.split(' ');
    if (parts.length != 5) return national;
    return [parts[0], parts[1], '••', '••', parts[4]].join(' ');
  }

  String? get _operator => guessOperator(digitsOf(_payout.text));

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _payout]) {
      controller.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _payout.dispose();
    super.dispose();
  }

  bool get _nameValid => _name.text.trim().length >= 2;
  bool get _payoutValid => isCameroonMobile(digitsOf(_payout.text)) && _operator != null;
  bool get _valid => _nameValid && (_kind == _Kind.person || _payoutValid);

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!_valid) return;
    setState(() => _saving = true);
    final api = ref.read(clientApiProvider);
    final name = _name.text.trim();
    try {
      await api.updateName(name);
      if (_kind == _Kind.shop) {
        await api.becomeMerchant(
          shopName: name,
          payoutPhone: '+237${digitsOf(_payout.text)}',
          payoutOperator: _operator!,
        );
      }
      if (mounted) widget.onDone();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final shop = _kind == _Kind.shop;
    final operator = _operator;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Maquette : « NOUVEAU COMPTE », titre 28, explication.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.welcomeKicker.toUpperCase(),
                style: TaraText.smallStrong.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: c.accentText,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(l.welcomeTitle, style: TaraText.titleForm.copyWith(fontSize: 28, color: c.textPrimary)),
              ),
              const SizedBox(height: 6),
              Text(
                l.welcomeBody,
                style: TaraText.text.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: c.textPrimary.withValues(alpha: .74),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BoxedField(
                label: shop ? l.shopNameLabel : l.yourName,
                hint: shop ? l.shopNameHint : l.yourNameHint,
                controller: _name,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                autofillHints: shop ? null : const [AutofillHints.name],
              ),
              if (_tried && !_nameValid) ...[const SizedBox(height: 6), ErrorLine(l.requiredField)],
              const SizedBox(height: 14),
              Text(
                l.kindQuestion,
                style: TaraText.text.copyWith(fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 14),
              LiquidSegmented<_Kind>(
                segments: [(_Kind.person, l.kindPerson), (_Kind.shop, l.kindShop)],
                selected: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 14),
              _Parcels(shop: shop),
              const SizedBox(height: 14),
              Text(
                shop ? l.kindShopHelp : l.kindPersonHelp,
                style: TaraText.label.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: c.textPrimary.withValues(alpha: .74),
                ),
              ),
              if (shop) ...[
                const SizedBox(height: 14),
                if (_editPayout)
                  BoxedField(
                    label: l.payoutNumber,
                    helper: l.payoutReceives,
                    hint: l.phoneHint,
                    controller: _payout,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                    trailing: operator == null ? null : _OperatorBadge(operator),
                  )
                else
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _editPayout = true),
                      child: BoxedField(
                        label: l.payoutNumber,
                        value: _masked(_payout.text),
                        helper: l.payoutReceives,
                        trailing: operator == null ? null : _OperatorBadge(operator),
                      ),
                    ),
                  ),
                if (_tried && !_payoutValid) ...[const SizedBox(height: 6), ErrorLine(l.phoneInvalid)],
              ],
            ],
          ),
        ),
      ],
    );
    return TaraScreen(
      blobs: _blobs,
      // Maquette : le bouton reste en bas ; le contenu défile au-dessus s'il manque de place.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SingleChildScrollView(child: content)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[ErrorLine(_error!), const SizedBox(height: 10)],
                PrimaryButton(label: l.continueLabel, loading: _saving, onPressed: _submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo de l'opérateur Mobile Money (30, coins 8, fond blanc, liseré).
class _OperatorBadge extends StatelessWidget {
  const _OperatorBadge(this.code);
  final String code;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(color: Color.fromRGBO(22, 18, 14, .08), spreadRadius: 1)],
    ),
    clipBehavior: Clip.antiAlias,
    child: OperatorLogo(code, size: 30),
  );
}

/// Colis en 3D de la maquette : un grand pour soi ; trois pour une boutique.
class _Parcels extends StatelessWidget {
  const _Parcels({required this.shop});
  final bool shop;

  @override
  Widget build(BuildContext context) {
    // Centres relevés sur la maquette, depuis le milieu de la zone de 150 : un colis de 90 ;
    // pour une boutique, la rangée 90, 58, 46 centrée.
    final cubes = shop
        ? const [
            (90.0, -39.0, 0.0, Duration.zero, 10),
            (58.0, 19.0, 30.0, Duration(milliseconds: 500), 7),
            (46.0, 61.0, -20.0, Duration(seconds: 1), 8),
          ]
        : const [(90.0, 0.0, 0.0, Duration.zero, 10)];
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final (size, dx, dy, delay, seconds) in cubes)
            Transform.translate(
              // Le colis est dessiné en haut de son cadre (le bas sert au flottement).
              offset: Offset(dx, dy + size * .125),
              child: Parcel3D(
                size: size,
                shadow: false,
                period: Duration(seconds: seconds),
                bobPeriod: const Duration(seconds: 3),
                bobDelay: delay,
              ),
            ),
        ],
      ),
    );
  }
}
