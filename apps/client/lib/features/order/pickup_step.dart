import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
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
        StepHeading(title: l.pickupTitle, body: l.pickupBody),
        const SizedBox(height: 10),
        switch (addresses) {
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final address in value) ...[
                AddressChoice(
                  icon: _iconFor(address.label),
                  // « Boutique · Akwa », puis le repère (et la confirmation par une livraison).
                  title: [address.label ?? address.landmark, ?address.neighborhood?.name].join(' · '),
                  subtitle: address.label == null ? '' : address.landmark,
                  badge: address.verified ? l.addressVerifiedShort : null,
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
        DashedAction(label: l.newAddressOnMap, icon: TaraIcons.plus, onTap: onAddAddress),
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

/// Choix en radio des maquettes : petite tuile orange (ou logo), titre et détail, rond à
/// cocher ; bord orange de 2 et fond teinté quand il est choisi.
class AddressChoice extends StatelessWidget {
  const AddressChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
    this.leading,
  });

  final TaraIconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Mention ajoutée au détail (« confirmée par une livraison ✓ »).
  final String? badge;

  /// Image à la place de l'icône (logo de l'opérateur Mobile Money).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final detail = [if (subtitle.trim().isNotEmpty) subtitle.trim(), ?badge].join(' · ');
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 60),
          padding: EdgeInsets.symmetric(horizontal: selected ? 13 : 14, vertical: selected ? 9 : 10),
          decoration: BoxDecoration(
            color: selected ? const Color.fromRGBO(255, 138, 0, .08) : boxedFieldFill(c),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFFFF8A00) : boxedFieldBorder(c),
              width: selected ? 2 : 1,
            ),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(140, 70, 10, .05), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Row(
            children: [
              leading ??
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 177, 92, .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TaraIcon(icon, size: 18, color: c.accentText),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detail, style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre d'une étape (maquettes) : 22 en Sora, phrase d'aide 13 dessous.
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: TaraText.titleForm.copyWith(color: c.textPrimary, fontSize: 22)),
        ),
        const SizedBox(height: 10),
        Text(body, style: TaraText.label.copyWith(color: c.textSecondary, fontSize: 13, height: 1.35)),
      ],
    );
  }
}

/// « Nouvelle adresse sur la carte » : bouton en pointillés orange (maquette).
class DashedAction extends StatelessWidget {
  const DashedAction({super.key, required this.label, required this.icon, required this.onTap});
  final String label;
  final TaraIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Squish(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: const DashedRRectPainter(color: Color.fromRGBO(255, 177, 92, .6)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TaraIcon(icon, size: 18, color: c.accentText),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TaraText.text.copyWith(color: c.accentText, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bord en pointillés arrondi des maquettes (1,5 px, tirets de 5).
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, this.radius = 18});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(.75);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) => old.color != color || old.radius != radius;
}
