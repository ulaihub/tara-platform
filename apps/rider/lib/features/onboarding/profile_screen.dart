import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/phone_format.dart';
import 'onboarding_header.dart';

enum _Vehicle { motorbike, car, tricycle }

/// 03 · Inscription — profil. Pas de vélo au lancement ; garant facultatif (solde prépayé,
/// décision 36) ; contact d'urgence facultatif (prévenu par SMS en cas d'alerte). Chacun se
/// remplit en entier ou pas du tout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _plate = TextEditingController();
  final _guarantorName = TextEditingController();
  final _guarantorPhone = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  _Vehicle _vehicle = _Vehicle.motorbike;
  bool _saving = false;
  bool _tried = false;
  String? _error;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.05), size: 260, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.35, 0.7), size: 220, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 5)),
  ];

  List<TextEditingController> get _all => [
    _first,
    _last,
    _plate,
    _guarantorName,
    _guarantorPhone,
    _contactName,
    _contactPhone,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _all) {
      controller.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _name(TextEditingController c) => c.text.trim().length >= 2;
  bool _phone(TextEditingController c) => isCameroonMobile(digitsOf(c.text));
  bool get _contactStarted => _contactName.text.trim().isNotEmpty || _contactPhone.text.trim().isNotEmpty;
  bool get _contactValid => !_contactStarted || (_name(_contactName) && _phone(_contactPhone));
  bool get _guarantorStarted => _guarantorName.text.trim().isNotEmpty || _guarantorPhone.text.trim().isNotEmpty;
  bool get _guarantorValid => !_guarantorStarted || (_name(_guarantorName) && _phone(_guarantorPhone));
  bool get _valid => _name(_first) && _name(_last) && _guarantorValid && _contactValid;

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!_valid) return;
    setState(() => _saving = true);
    final api = ref.read(riderApiProvider);
    try {
      await api.updateName('${_first.text.trim()} ${_last.text.trim()}');
      await api.apply(
        vehicleType: switch (_vehicle) {
          _Vehicle.motorbike => 'MOTORBIKE',
          _Vehicle.car => 'CAR',
          _Vehicle.tricycle => 'TRICYCLE',
        },
        plateNumber: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
        guarantor: _guarantorStarted
            ? (name: _guarantorName.text.trim(), phone: '+237${digitsOf(_guarantorPhone.text)}')
            : null,
        emergencyContact: _contactStarted
            ? (name: _contactName.text.trim(), phone: '+237${digitsOf(_contactPhone.text)}')
            : null,
      );
      if (mounted) widget.onDone();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _phoneField(String label, TextEditingController controller, {String? error}) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaraTextField(
          label: label,
          hint: l.phoneHint,
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
          leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
        ),
        if (error != null) ...[const SizedBox(height: 6), ErrorLine(error)],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    String? required(bool ok) => _tried && !ok ? l.requiredField : null;

    /// [started] : l'autre champ du même bloc facultatif est rempli.
    String? phoneError(TextEditingController controller, {required bool started}) {
      if (!_tried) return null;
      if (controller.text.trim().isEmpty) return started ? l.requiredField : null;
      return _phone(controller) ? null : l.phoneInvalid;
    }

    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          OnboardingHeader(
            step: 1,
            total: 2,
            name: l.stepProfile,
            progress: .5,
            trailing: '50 %',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text(l.becomeRider, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(l.becomeRiderBody, style: TaraText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          GlassCard(
            radius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                const SizedBox(height: 18),
                Text(l.vehicle, style: TaraText.label.copyWith(color: c.textSecondary)),
                const SizedBox(height: 8),
                ChoiceChips<_Vehicle>(
                  // Petit écran et grand texte : deux colonnes, sans couper « Voiture » en deux.
                  columns: MediaQuery.sizeOf(context).width < 380 && MediaQuery.textScalerOf(context).scale(10) > 11
                      ? 2
                      : 3,
                  options: [
                    ChoiceOption(_Vehicle.motorbike, l.vehicleMotorbike),
                    ChoiceOption(_Vehicle.car, l.vehicleCar),
                    ChoiceOption(_Vehicle.tricycle, l.vehicleTricycle),
                  ],
                  selected: _vehicle,
                  onSelected: (value) => setState(() => _vehicle = value),
                ),
                const SizedBox(height: 18),
                _Field(label: l.plateNumber, hint: l.plateHint, controller: _plate, caps: true),
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
                Text(l.guarantor, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(l.guarantorHelp, style: TaraText.small.copyWith(color: c.textTertiary)),
                const SizedBox(height: 14),
                _Field(
                  label: l.guarantorName,
                  controller: _guarantorName,
                  error: _tried && _guarantorStarted && !_name(_guarantorName) ? l.requiredField : null,
                ),
                const SizedBox(height: 14),
                _phoneField(
                  l.guarantorPhone,
                  _guarantorPhone,
                  error: phoneError(_guarantorPhone, started: _guarantorStarted),
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
                Text(l.emergencyContact, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 10),
                InfoNote(text: l.emergencyHelp, icon: TaraIcons.shield),
                const SizedBox(height: 14),
                _Field(
                  label: l.emergencyName,
                  controller: _contactName,
                  error: _tried && _contactStarted && !_name(_contactName) ? l.requiredField : null,
                ),
                const SizedBox(height: 14),
                _phoneField(
                  l.emergencyPhone,
                  _contactPhone,
                  error: phoneError(_contactPhone, started: _contactStarted),
                ),
              ],
            ),
          ),
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
