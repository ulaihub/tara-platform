import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';
import 'package:tara_ui/vehicle_labels.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../course/course_page.dart';

/// « Ma moto » (profil) : marque, couleur et plaque, montrées à l'expéditeur avec la photo
/// du livreur pour qu'il le reconnaisse à l'arrivée.
class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key, required this.profile, required this.onBack, required this.onSaved});

  final RiderProfile profile;
  final VoidCallback onBack;
  final ValueChanged<RiderProfile> onSaved;

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 280, colors: BlobSpec.brand, blur: 70)];

  late String? _brand = widget.profile.vehicleBrand;
  late String? _color = widget.profile.vehicleColor;
  late final _plate = TextEditingController(text: widget.profile.plateNumber ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final plate = _plate.text.trim();
      final profile = await ref
          .read(riderApiProvider)
          .setVehicle(brand: _brand, color: _color, plateNumber: plate.length >= 3 ? plate : null);
      if (mounted) widget.onSaved(profile);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context);
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          CourseHeader(
            kicker: l.tabProfile,
            title: l.vehicleTitle,
            subtitle: l.vehicleSubtitle,
            onBack: _busy ? () {} : widget.onBack,
          ),
          const SizedBox(height: 18),
          InfoNote(text: l.vehicleHelp, icon: TaraIcons.moto),
          const SizedBox(height: 18),
          Text(l.vehicleColor, style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChoiceChips<String>(
            columns: 3,
            height: 44,
            selected: _color,
            onSelected: (value) => setState(() => _color = value),
            options: [
              for (final MapEntry(key: code, value: tint) in vehicleColors.entries)
                ChoiceOption(
                  code,
                  vehicleColorName(code, locale),
                  leading: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.textPrimary.withValues(alpha: .3)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(l.vehicleBrand, style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChoiceChips<String>(
            columns: 3,
            height: 44,
            selected: _brand,
            onSelected: (value) => setState(() => _brand = value),
            options: [for (final code in vehicleBrands) ChoiceOption(code, vehicleBrandName(code, locale))],
          ),
          const SizedBox(height: 18),
          TaraTextField(
            label: l.vehiclePlate,
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: PrimaryButton(label: l.save, icon: TaraIcons.check, loading: _busy, onPressed: _save),
      ),
    );
  }
}
