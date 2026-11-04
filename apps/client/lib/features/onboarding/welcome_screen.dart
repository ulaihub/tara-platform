import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

enum _Kind { person, shop }

/// Catégories proposées pour une boutique (texte libre côté serveur).
const shopCategories = ['FASHION', 'BEAUTY', 'ELECTRONICS', 'FOOD', 'HOME', 'OTHER'];

/// 03 · Bienvenue (première connexion, non dessiné : style Tara) : prénom et nom, qui
/// figurent dans les SMS des destinataires ; mode marchand facultatif (A2) avec la
/// boutique et le numéro Mobile Money des reversements, RCCM et NIU facultatifs.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.me, required this.onDone, required this.onLogout});

  final Me me;
  final VoidCallback onDone;
  final VoidCallback onLogout;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.8), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _shop = TextEditingController();
  late final _payout = TextEditingController(text: _national(widget.me.phone));
  final _rccm = TextEditingController();
  final _niu = TextEditingController();
  _Kind _kind = _Kind.person;
  String? _category;
  String? _operator;
  bool _legalIds = false;
  bool _tried = false;
  bool _saving = false;
  String? _error;

  List<TextEditingController> get _all => [_first, _last, _shop, _payout, _rccm, _niu];

  static String _national(String phone) {
    final digits = digitsOf(phone).replaceFirst(RegExp('^237'), '');
    return PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
  }

  @override
  void initState() {
    super.initState();
    _operator = guessOperator(digitsOf(_payout.text));
    for (final controller in _all) {
      controller.addListener(() => setState(() => _error = null));
    }
    _payout.addListener(() {
      final guess = guessOperator(digitsOf(_payout.text));
      if (guess != null && guess != _operator) setState(() => _operator = guess);
    });
  }

  @override
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _name(TextEditingController c) => c.text.trim().length >= 2;
  bool get _payoutValid => isCameroonMobile(digitsOf(_payout.text)) && _operator != null;
  bool get _valid => _name(_first) && _name(_last) && (_kind == _Kind.person || (_name(_shop) && _payoutValid));

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!_valid) return;
    setState(() => _saving = true);
    final api = ref.read(clientApiProvider);
    try {
      await api.updateName('${_first.text.trim()} ${_last.text.trim()}');
      if (_kind == _Kind.shop) {
        await api.becomeMerchant(
          shopName: _shop.text.trim(),
          category: _category,
          payoutPhone: '+237${digitsOf(_payout.text)}',
          payoutOperator: _operator!,
          rccm: _rccm.text.trim().isEmpty ? null : _rccm.text.trim(),
          niu: _niu.text.trim().isEmpty ? null : _niu.text.trim(),
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
    final operators = ref.watch(appConfigProvider).value?.operators ?? const <MobileMoneyOperator>[];
    String? required(bool ok) => _tried && !ok ? l.requiredField : null;
    final shop = _kind == _Kind.shop;

    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.logout, onPressed: _saving ? null : widget.onLogout),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(l.welcomeTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(l.welcomeBody, style: TaraText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          GlassCard(
            radius: 26,
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    label: l.firstName,
                    controller: _first,
                    error: required(_name(_first)),
                    autofill: AutofillHints.givenName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: l.lastName,
                    controller: _last,
                    error: required(_name(_last)),
                    autofill: AutofillHints.familyName,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            radius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.kindQuestion, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 12),
                LiquidSegmented<_Kind>(
                  segments: [(_Kind.person, l.kindPerson), (_Kind.shop, l.kindShop)],
                  selected: _kind,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                const SizedBox(height: 10),
                Text(shop ? l.kindShopHelp : l.kindPersonHelp, style: TaraText.small.copyWith(color: c.textTertiary)),
                if (shop) ...[
                  const SizedBox(height: 18),
                  _Field(label: l.shopName, hint: l.shopNameHint, controller: _shop, error: required(_name(_shop))),
                  const SizedBox(height: 16),
                  Text(l.shopCategory, style: TaraText.label.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  ChoiceChips<String>(
                    options: [for (final code in shopCategories) ChoiceOption(code, _categoryLabel(l, code))],
                    selected: _category,
                    onSelected: (value) => setState(() => _category = value == _category ? null : value),
                  ),
                ],
              ],
            ),
          ),
          if (shop) ...[
            const SizedBox(height: 14),
            GlassCard(
              radius: 26,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.payoutTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(l.payoutHelp, style: TaraText.small.copyWith(color: c.textTertiary)),
                  const SizedBox(height: 14),
                  ChoiceChips<String>(
                    options: [for (final operator in operators) ChoiceOption(operator.code, operator.name)],
                    selected: _operator,
                    onSelected: (value) => setState(() => _operator = value),
                  ),
                  const SizedBox(height: 14),
                  TaraTextField(
                    label: l.payoutNumber,
                    hint: l.phoneHint,
                    controller: _payout,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                    leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
                  ),
                  if (_tried && !_payoutValid) ...[const SizedBox(height: 6), ErrorLine(l.phoneInvalid)],
                  const SizedBox(height: 14),
                  if (_legalIds) ...[
                    _Field(label: l.rccm, hint: l.rccmHint, controller: _rccm, caps: true),
                    const SizedBox(height: 14),
                    _Field(label: l.niu, hint: l.niuHint, controller: _niu, caps: true),
                  ] else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TaraLink(label: l.addLegalIds, onPressed: () => setState(() => _legalIds = true)),
                    ),
                ],
              ),
            ),
          ],
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[ErrorLine(_error!), const SizedBox(height: 10)],
            PrimaryButton(label: l.continueLabel, icon: TaraIcons.arrowRight, loading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(AppLocalizations l, String code) => switch (code) {
    'FASHION' => l.categoryFashion,
    'BEAUTY' => l.categoryBeauty,
    'ELECTRONICS' => l.categoryElectronics,
    'FOOD' => l.categoryFood,
    'HOME' => l.categoryHome,
    _ => l.categoryOther,
  };
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.autofill,
    this.caps = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final String? autofill;
  final bool caps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaraTextField(
          label: label,
          hint: hint,
          controller: controller,
          textInputAction: TextInputAction.next,
          autofillHints: autofill == null ? null : [autofill!],
          textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.words,
        ),
        if (error != null) ...[const SizedBox(height: 6), ErrorLine(error!)],
      ],
    );
  }
}
