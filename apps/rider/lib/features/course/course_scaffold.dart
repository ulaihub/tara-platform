import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/dashed.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/location/online_controller.dart';
import '../../l10n/app_localizations.dart';
import '../map/tara_map.dart';
import 'course_header.dart';

/// Distance approchée entre deux points (équirectangulaire), suffisante à l'échelle d'une ville.
double courseDistance(double lat1, double lng1, double lat2, double lng2) {
  const metersPerDegree = 111320.0;
  final dLat = (lat1 - lat2) * metersPerDegree;
  final dLng = (lng1 - lng2) * metersPerDegree * math.cos(lat1 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// Titre de l'en-tête selon l'itinéraire et la distance à l'étape (null : position inconnue).
typedef CourseTitle = String Function(RiderRoute? route, double? metersToStop);

/// Cadre des écrans de course (08, 09, 11) : carte plein écran avec l'itinéraire vers
/// l'étape, en-tête (retour, référence, étape, SOS), bouton « Itinéraire » et panneau en
/// verre qui défile, bouton principal en bas. L'itinéraire est redemandé quand le livreur
/// a bougé de plus de 150 m, ou toutes les 2 minutes.
class CourseScaffold extends ConsumerStatefulWidget {
  const CourseScaffold({
    super.key,
    required this.order,
    required this.stop,
    required this.title,
    required this.onBack,
    required this.onSos,
    required this.children,
    required this.footer,
    this.panelRatio = .62,
  });

  /// Part de l'écran couverte par le panneau (maquette : 62 % à l'enlèvement, 70 % à la
  /// livraison) ; plus haut sur un petit écran ou avec le texte agrandi.
  final double panelRatio;

  final RiderOrder order;
  final MapStop stop;
  final CourseTitle title;
  final VoidCallback onBack;
  final VoidCallback onSos;
  final List<Widget> children;
  final Widget footer;

  @override
  ConsumerState<CourseScaffold> createState() => _CourseScaffoldState();
}

class _CourseScaffoldState extends ConsumerState<CourseScaffold> {
  final _map = TaraMapHandle();
  late final OnlineController _online;
  bool _following = true;
  RiderRoute? _route;
  GeoPoint? _routeFrom;
  DateTime? _routeAt;

  @override
  void initState() {
    super.initState();
    _online = ref.read(onlineControllerProvider)..addListener(_onPosition);
    _onPosition();
  }

  @override
  void dispose() {
    _online.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final position = _online.lastPosition;
    if (position == null) return;
    final from = _routeFrom;
    final moved =
        from == null || courseDistance(from.latitude, from.longitude, position.latitude, position.longitude) > 150;
    final stale = _routeAt == null || DateTime.now().difference(_routeAt!) > const Duration(minutes: 2);
    if (!moved && !stale) return;
    _routeFrom = position;
    _routeAt = DateTime.now();
    unawaited(_loadRoute(position));
  }

  Future<void> _loadRoute(GeoPoint from) async {
    try {
      final route = await ref.read(riderApiProvider).route(widget.order.id, from);
      if (mounted) setState(() => _route = route);
    } catch (_) {
      // Sans réseau : la carte garde le dernier itinéraire, le bouton Itinéraire reste.
    }
  }

  Future<void> _openDirections() async {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final stop = widget.stop;
    final google =
        order.googleMapsUrl ??
        'https://www.google.com/maps/dir/?api=1&destination=${stop.latitude},${stop.longitude}&travelmode=driving';
    final waze = order.wazeUrl ?? 'https://waze.com/ul?ll=${stop.latitude},${stop.longitude}&navigate=yes';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassPanel(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.openWith, style: TaraText.cardTitle.copyWith(color: TaraColors.of(context).textPrimary)),
              const SizedBox(height: 14),
              GlassButton(
                label: 'Google Maps',
                icon: TaraIcons.navigation,
                onPressed: () => Navigator.pop(context, google),
              ),
              const SizedBox(height: 10),
              GlassButton(label: 'Waze', icon: TaraIcons.navigation, onPressed: () => Navigator.pop(context, waze)),
            ],
          ),
        ),
      ),
    );
    if (choice != null) await launchUrl(Uri.parse(choice), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final online = ref.watch(onlineControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Panneau du bas comme sur la maquette ; la carte visible au-dessus.
    // Petit écran ou texte agrandi : panneau plus haut, la carte garde le haut de l'écran.
    final small = size.height / MediaQuery.textScalerOf(context).scale(1) < 560;
    final ratio = small ? math.max(widget.panelRatio, .72) : widget.panelRatio;
    final fullPanel = (size.height * ratio).clamp(340.0, size.height - insets.top - 150);
    // Clavier ouvert : le panneau remonte sans passer sous l'en-tête.
    final panelHeight = keyboard > 0 ? math.min(fullPanel, size.height - keyboard - insets.top - 70) : fullPanel;
    final stop = widget.stop;

    return TaraScreen(
      safeTop: false,
      safeBottom: false,
      background: Positioned.fill(
        child: ListenableBuilder(
          listenable: online,
          builder: (context, _) => TaraMap(
            rider: online.lastPosition,
            handle: _map,
            stop: stop,
            route: _route,
            framePadding: EdgeInsets.fromLTRB(48, insets.top + 96, 48, panelHeight + 64),
            onFollowChanged: (value) => setState(() => _following = value),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: .85), c.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: insets.top + 8,
            child: ListenableBuilder(
              listenable: online,
              builder: (context, _) {
                final here = online.lastPosition;
                final meters = here == null
                    ? null
                    : courseDistance(here.latitude, here.longitude, stop.latitude, stop.longitude);
                return CourseHeader(
                  reference: l.courseRefRecorded(widget.order.reference),
                  title: widget.title(_route, meters),
                  onBack: widget.onBack,
                  onSos: widget.onSos,
                );
              },
            ),
          ),
          Positioned(
            right: 16,
            bottom: panelHeight + keyboard + 14,
            child: Row(
              children: [
                if (!_following) ...[
                  GlassIconButton(
                    icon: TaraIcons.navigation,
                    label: l.recenterMap,
                    badge: true,
                    onPressed: _map.recenter,
                  ),
                  const SizedBox(width: 10),
                ],
                _DirectionsButton(label: l.directions, onPressed: _openDirections),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            height: panelHeight,
            child: GlassPanel(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + (keyboard > 0 ? 0 : insets.bottom)),
              child: Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      // Fondu en bas : il reste du contenu à faire défiler.
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                          stops: [0, .94, 1],
                        ).createShader(bounds),
                        child: SingleChildScrollView(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                        ),
                      ),
                    ),
                    widget.footer,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Appel d'un vendeur ou d'un client depuis une course.
Future<void> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

/// Avertissement rouge dans le panneau (zone interdite aux motos, adresse éloignée).
class CourseWarning extends StatelessWidget {
  const CourseWarning(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return TintBox(
      tone: TintTone.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaraIcon(TaraIcons.alertCircle, size: 18, color: c.dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TaraText.label.copyWith(color: c.dangerText)),
          ),
        ],
      ),
    );
  }
}

/// Libellé d'un champ du panneau : « Code d'enlèvement · donné par le vendeur ».
class CourseFieldLabel extends StatelessWidget {
  const CourseFieldLabel(this.label, {super.key, this.hint});
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (hint != null)
            TextSpan(
              text: ' · $hint',
              style: TextStyle(fontWeight: FontWeight.w500, color: c.textTertiary),
            ),
        ],
      ),
      style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
    );
  }
}

/// « Itinéraire » : bouton clair sur la carte, ouvre Google Maps ou Waze (E2).
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.94),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TaraIcon(TaraIcons.navigation, size: 18, color: TaraBrand.onBrand),
              const SizedBox(width: 8),
              Text(
                label,
                style: TaraText.text.copyWith(color: TaraBrand.onBrand, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vendeur ou client : initiales, nom, quartier et repère, bouton d'appel.
class PartyRow extends StatelessWidget {
  const PartyRow({
    super.key,
    required this.name,
    required this.line,
    required this.callLabel,
    required this.onCall,
    this.note,
  });
  final String name;
  final String line;

  /// Consigne de l'expéditeur, en petit sous l'adresse.
  final String? note;
  final String callLabel;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Row(
      children: [
        InitialsAvatar(name: name, size: 48, round: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TaraText.cardTitle.copyWith(color: c.textPrimary, fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                line,
                style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(
                  '« $note »',
                  style: TaraText.small.copyWith(color: c.textTertiary, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        if (onCall != null) ...[const SizedBox(width: 10), CallButton(label: callLabel, onPressed: onCall)],
      ],
    );
  }
}

/// Argent à encaisser (à l'enlèvement ou à la remise) : intitulé, précision et montant.
class CollectBox extends StatelessWidget {
  const CollectBox({super.key, required this.amount, required this.title, required this.body});
  final int amount;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final amountText = AmountText(amount, unit: 'F', style: TaraText.amountL.copyWith(fontSize: 22));
    final texts = [
      Text(
        title,
        style: TaraText.label.copyWith(color: c.accentStrongText, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(body, style: TaraText.small.copyWith(color: c.textSecondary)),
    ];
    return TintBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Peu de place (petit écran, texte agrandi) : le montant passe sous l'intitulé.
          final stacked = constraints.maxWidth / scale < 290;
          return Row(
            crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              const IconTile(icon: TaraIcons.cash, size: 36, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    texts[0],
                    if (stacked) ...[const SizedBox(height: 2), amountText],
                    ...texts.skip(1),
                  ],
                ),
              ),
              if (!stacked) ...[const SizedBox(width: 10), amountText],
            ],
          );
        },
      ),
    );
  }
}

/// Photo de preuve (colis, remise) : tuile en pointillés tant qu'elle manque, vignette ensuite.
class ProofPhotoTile extends StatelessWidget {
  const ProofPhotoTile({
    super.key,
    required this.path,
    required this.takenAt,
    required this.onTake,
    required this.title,
    required this.hint,
    required this.takenLabel,
  });
  final String? path;
  final DateTime? takenAt;
  final VoidCallback? onTake;
  final String title;
  final String hint;

  /// « Photo du colis · prise à 14:32 ».
  final String Function(String time) takenLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final photo = path;
    if (photo == null) {
      return Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTake,
          child: CustomPaint(
            painter: DashedBorderPainter(color: c.textTertiary.withValues(alpha: .6), radius: 20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const IconTile(icon: TaraIcons.camera, size: 52, radius: 15),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(hint, style: TaraText.small.copyWith(color: c.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final at = takenAt;
    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: 56,
              child: Image.file(
                File(photo),
                fit: BoxFit.cover,
                cacheWidth: 168,
                errorBuilder: (_, _, _) => ColoredBox(color: c.mapBlocks),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                TaraIcon(TaraIcons.check, size: 18, color: c.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(takenLabel(time), style: TaraText.label.copyWith(color: c.textPrimary)),
                ),
              ],
            ),
          ),
          TaraLink(label: l.retakePhoto, onPressed: onTake),
        ],
      ),
    );
  }
}

/// Quel colis : son numéro (écrit dessus par l'expéditeur qui en envoie plusieurs), ce qu'il
/// contient et pour qui. À l'enlèvement, le livreur sait lequel prendre ; à la livraison,
/// lequel remettre quand il en transporte deux.
class ParcelCard extends StatelessWidget {
  const ParcelCard({super.key, required this.order, required this.title, this.showRecipient = true});

  final RiderOrder order;

  /// « Colis à récupérer », « Colis à remettre ».
  final String title;

  /// Prénom et quartier du destinataire (inutile sur l'écran de livraison, qui les affiche).
  final bool showRecipient;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final number = order.batchNumber;
    final what =
        order.packageDescription?.trim().nullIfEmpty ??
        switch (order.packageSize) {
          'S' => l.packageSmall,
          'L' || 'XL' => l.packageLarge,
          'BULKY' => l.packageBulky,
          _ => l.packageMedium,
        };
    final first = order.recipient.name?.trim().split(RegExp(r'\s+')).first;
    final place = order.dropoff.neighborhood ?? order.dropoff.landmark;
    final forWhom = first == null || first.isEmpty ? place : l.parcelFor(first, place);
    return GlassCard(
      radius: 18,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: MergeSemantics(
        child: Row(
          children: [
            if (number != null)
              Semantics(
                label: l.parcelNumber(number),
                excludeSemantics: true,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    '$number',
                    style: TaraText.titleCourse.copyWith(color: TaraBrand.onBrand, fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else
              const IconTile(icon: TaraIcons.package, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (number == null ? title : '$title · ${l.parcelNumber(number)}').toUpperCase(),
                    style: TaraText.overline.copyWith(color: c.accentText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    what,
                    style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  if (showRecipient) Text(forWhom, style: TaraText.small.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
