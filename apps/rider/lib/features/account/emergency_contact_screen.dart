import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
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

/// Contact d'urgence (profil) : prévenu par SMS si le livreur déclenche une alerte SOS.
/// Ajout, modification ou retrait ; le serveur renvoie le dossier à jour.
class EmergencyContactScreen extends ConsumerStatefulWidget {
  const EmergencyContactScreen({super.key, required this.profile, required this.onBack, required this.onSaved});

  final RiderProfile profile;
  final VoidCallback onBack;
  final ValueChanged<RiderProfile> onSaved;

  @override
  ConsumerState<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends ConsumerState<EmergencyContactScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 280, colors: BlobSpec.brand, blur: 70)];

  late final _name = TextEditingController(text: widget.profile.emergencyContactName ?? '');
  late final _phone = TextEditingController(text: _national(widget.profile.emergencyContactPhone));
  bool _tried = false;
  bool _busy = false;
  String? _error;

  static String _national(String? phone) {
    final digits = digitsOf(phone ?? '').replaceFirst(RegExp('^237'), '');
    return PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _phone]) {
      controller.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _nameValid => _name.text.trim().length >= 2;
  bool get _phoneValid => isCameroonMobile(digitsOf(_phone.text));
  bool get _hasContact => widget.profile.emergencyContactPhone != null;

  Future<void> _run(Future<RiderProfile> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await action();
      if (mounted) widget.onSaved(profile);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_nameValid || !_phoneValid) return;
    final api = ref.read(riderApiProvider);
    await _run(() => api.setEmergencyContact(_name.text.trim(), '+237${digitsOf(_phone.text)}'));
  }

  Future<void> _remove() => _run(ref.read(riderApiProvider).removeEmergencyContact);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: _busy ? null : widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.emergencyContactTitle, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InfoNote(text: l.emergencyHelp, icon: TaraIcons.shield),
          const SizedBox(height: 16),
          TaraTextField(
            label: l.emergencyName,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          if (_tried && !_nameValid) ...[const SizedBox(height: 6), ErrorLine(l.requiredField)],
          const SizedBox(height: 14),
          TaraTextField(
            label: l.emergencyPhone,
            hint: l.phoneHint,
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneInputFormatter()],
            leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
          ),
          if (_tried && !_phoneValid) ...[const SizedBox(height: 6), ErrorLine(l.phoneInvalid)],
          if (_hasContact) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(
                label: l.removeContact,
                onPressed: _busy ? null : _remove,
                style: TaraText.label.copyWith(color: c.dangerText, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: PrimaryButton(label: l.save, icon: TaraIcons.check, loading: _busy, onPressed: _save),
      ),
    );
  }
}
