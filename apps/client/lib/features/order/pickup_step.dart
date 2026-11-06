import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';

/// Adresses d'enlèvement enregistrées : celles qui portent un libellé (Boutique, Maison…).
final pickupAddressesProvider = FutureProvider<List<Address>>((ref) async {
  final all = await ref.read(clientApiProvider).addresses();
  return [
    for (final address in all)
      if (address.label != null) address,
  ];
});

/// Étape 1 · Enlèvement : une adresse enregistrée, ou une nouvelle placée sur la carte.
class PickupStep extends ConsumerWidget {
  const PickupStep({super.key, required this.draft, required this.onAddAddress, this.showErrors = false});

  final OrderDraft draft;
  final VoidCallback onAddAddress;

  /// « Continuer » a été touché sans adresse choisie.
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final addresses = ref.watch(pickupAddressesProvider);
    // Une seule adresse, ou la boutique d'un marchand : choisie d'office.
    final list = addresses.value;
    if (draft.pickup == null && list != null && list.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        draft.pickup ??= list.first;
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.pickupTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 8),
        Text(l.pickupBody, style: TaraText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 18),
        switch (addresses) {
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final address in value) ...[
                AddressChoice(
                  icon: _iconFor(address.label),
                  title: address.label ?? address.landmark,
                  subtitle: address.summary,
                  selected: draft.pickup?.id == address.id,
                  onTap: () => draft.pickup = address,
                ),
                const SizedBox(height: 10),
              ],
              if (value.isEmpty) ...[
                Text(l.noPickupYet, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
                const SizedBox(height: 12),
              ],
            ],
          ),
          AsyncError() => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.addressesError, style: TaraText.label.copyWith(color: c.textSecondary)),
                ),
                TaraLink(label: l.retry, onPressed: () => ref.invalidate(pickupAddressesProvider)),
              ],
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: GooLoader(compact: true)),
          ),
        },
        GlassButton(label: l.newAddress, icon: TaraIcons.mapPin, color: c.accentText, onPressed: onAddAddress),
        if (showErrors && draft.pickup == null) ...[const SizedBox(height: 10), ErrorLine(l.pickupRequired)],
      ],
    );
  }

  static TaraIconData _iconFor(String? label) => switch (label?.toLowerCase()) {
    final l? when l.contains('bout') || l.contains('shop') => TaraIcons.package,
    final l? when l.contains('mais') || l.contains('home') => TaraIcons.home,
    _ => TaraIcons.mapPin,
  };
}

/// Adresse à choisir : icône, titre, détail, coche quand elle est choisie.
class AddressChoice extends StatelessWidget {
  const AddressChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final TaraIconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Mention sous le détail (« Adresse confirmée par une livraison »).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: selected ? c.chipSelected : null,
            color: selected ? null : c.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? c.chipSelectedBorder : c.glassBorder,
              width: selected ? c.chipSelectedBorderWidth : 1,
            ),
          ),
          child: Row(
            children: [
              IconTile(icon: icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TaraText.small.copyWith(color: c.textSecondary)),
                    if (badge != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TaraIcon(TaraIcons.shieldCheck, size: 14, color: c.success),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              badge!,
                              style: TaraText.small.copyWith(color: c.success, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 1 : 0,
                child: TaraIcon(TaraIcons.check, size: 22, color: c.accentText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
