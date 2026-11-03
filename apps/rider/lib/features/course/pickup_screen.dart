import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../core/location/online_controller.dart';
import '../../design/components/buttons.dart';
import '../../design/components/dashed.dart';
import '../../design/components/glass.dart';
import '../../design/components/inputs.dart';
import '../../design/components/layout.dart';
import '../../design/components/progress.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../map/tara_map.dart';

import 'course_header.dart';

/// 08 · Enlèvement : itinéraire jusqu'au vendeur, montant à encaisser sur place, code de
/// l'expéditeur et photo du colis. « Colis récupéré » passe par la file hors connexion.
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onPickedUp,
    this.now,
  });

  final RiderOrder order;

  /// Retour à l'accueil, la course reste en cours.
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis récupéré : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onPickedUp;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  final _code = TextEditingController();
  final _map = TaraMapHandle();
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  bool _following = true;
  String? _error;
  String? _refusedActionId;

  late final OnlineController _online;
  RiderRoute? _route;
  GeoPoint? _routeFrom;
  DateTime? _routeAt;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    // Enlèvement refusé resté dans la file (écran rouvert) : on reprend où il en était.
    final refused = ref.read(courseActionsProvider).refusedPickup(widget.order.id);
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
    }
    _online = ref.read(onlineControllerProvider)..addListener(_onPosition);
    _onPosition();
  }

  @override
  void dispose() {
    _online.removeListener(_onPosition);
    _code.dispose();
    super.dispose();
  }

  /// Itinéraire redemandé quand le livreur a bougé de plus de 150 m, ou toutes les 2 min.
  void _onPosition() {
    final position = _online.lastPosition;
    if (position == null) return;
    final from = _routeFrom;
    final moved = from == null || _distance(from, position) > 150;
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

  static double _distance(GeoPoint a, GeoPoint b) {
    // Approximation locale (équirectangulaire), suffisante à l'échelle d'une ville.
    const metersPerDegree = 111320.0;
    final dLat = (a.latitude - b.latitude) * metersPerDegree;
    final dLng = (a.longitude - b.longitude) * metersPerDegree * math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  Future<void> _takePhoto() async {
    final path = await ref.read(takeProofPhotoProvider)();
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      _photoAt = widget.now?.call() ?? DateTime.now();
      _error = null;
    });
  }

  Future<GeoPoint?> _position() async =>
      ref.read(onlineControllerProvider).lastPosition ?? await ref.read(positionSourceProvider).current();

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final photo = _photoPath;
    if (photo == null || _code.text.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final at = await _position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _busy = false;
        _error = l.noPositionYet;
      });
      return;
    }
    final result = await ref
        .read(courseActionsProvider)
        .pickUp(widget.order, code: _code.text, photoPath: photo, at: at, retryActionId: _refusedActionId);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
        _code.clear();
      });
      return;
    }
    widget.onPickedUp(result.outcome);
  }

  Future<void> _openDirections() async {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final google =
        order.googleMapsUrl ??
        'https://www.google.com/maps/dir/?api=1&destination=${order.pickup.latitude},${order.pickup.longitude}&travelmode=driving';
    final waze =
        order.wazeUrl ?? 'https://waze.com/ul?ll=${order.pickup.latitude},${order.pickup.longitude}&navigate=yes';
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

  Future<void> _call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final online = ref.watch(onlineControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Panneau du bas : 62 % de l'écran comme sur la maquette ; la carte visible au-dessus.
    // Petit écran ou texte agrandi : panneau plus haut, la carte garde le haut de l'écran.
    final small = size.height / MediaQuery.textScalerOf(context).scale(1) < 560;
    final fullPanel = (size.height * (small ? .72 : .62)).clamp(340.0, size.height - insets.top - 150);
    // Clavier ouvert : le panneau remonte sans passer sous l'en-tête.
    final panelHeight = keyboard > 0 ? math.min(fullPanel, size.height - keyboard - insets.top - 70) : fullPanel;
    final minutes = _route?.minutes;
    final steps = [l.stepPickup, if (order.collectAtDelivery > 0) l.stepCollect, l.stepDelivery];
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final phone = order.sender.phone ?? order.pickup.contactPhone;
    final ready = _photoPath != null && _code.text.length == 4;

    return TaraScreen(
      safeTop: false,
      safeBottom: false,
      background: Positioned.fill(
        child: ListenableBuilder(
          listenable: online,
          builder: (context, _) => TaraMap(
            rider: online.lastPosition,
            handle: _map,
            stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
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
            child: CourseHeader(
              reference: l.courseRefRecorded(order.reference),
              title: minutes == null ? l.toPickup : l.toPickupMinutes(minutes),
              onBack: widget.onBack,
              onSos: widget.onSos,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CourseStepper(labels: steps, activeIndex: 0),
                              const SizedBox(height: 14),
                              _PartyRow(
                                name: senderName,
                                line: order.pickup.line,
                                note: order.instructions,
                                callLabel: l.callPerson(senderName),
                                onCall: phone == null ? null : () => _call(phone),
                              ),
                              if (order.collectAtPickup > 0) ...[
                                const SizedBox(height: 12),
                                _CollectBox(amount: order.collectAtPickup),
                              ],
                              if (order.pickup.motorbikeRestricted) ...[
                                const SizedBox(height: 12),
                                TintBox(
                                  tone: TintTone.danger,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TaraIcon(TaraIcons.alertCircle, size: 18, color: c.dangerText),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          l.noMotoAddress,
                                          style: TaraText.label.copyWith(color: c.dangerText),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: l.pickupCodeLabel),
                                    TextSpan(
                                      text: ' · ${l.pickupCodeHint}',
                                      style: TextStyle(fontWeight: FontWeight.w500, color: c.textTertiary),
                                    ),
                                  ],
                                ),
                                style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              CodeCells(
                                length: 4,
                                controller: _code,
                                cellHeight: 56,
                                autofocus: false,
                                digitLabel: l.digitLabel,
                              ),
                              const SizedBox(height: 12),
                              _PhotoTile(path: _photoPath, takenAt: _photoAt, onTake: _busy ? null : _takePhoto),
                              if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PrimaryButton(
                      label: l.parcelCollected,
                      icon: TaraIcons.check,
                      loading: _busy,
                      onPressed: ready ? _submit : null,
                    ),
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
class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.name, required this.line, required this.callLabel, required this.onCall, this.note});
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

/// Espèces à encaisser auprès de l'expéditeur avant de prendre le colis.
class _CollectBox extends StatelessWidget {
  const _CollectBox({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return TintBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          const IconTile(icon: TaraIcons.cash, size: 36, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.collectAtPickupTitle,
                  style: TaraText.label.copyWith(color: c.accentStrongText, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(l.collectAtPickupBody, style: TaraText.small.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AmountText(amount, unit: 'F', style: TaraText.amountL.copyWith(fontSize: 22)),
        ],
      ),
    );
  }
}

/// Photo du colis : tuile en pointillés tant qu'elle manque, vignette ensuite.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.takenAt, required this.onTake});
  final String? path;
  final DateTime? takenAt;
  final VoidCallback? onTake;

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
                        Text(l.photoParcel, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(l.photoParcelHint, style: TaraText.small.copyWith(color: c.textTertiary)),
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
                  child: Text(l.photoParcelTaken(time), style: TaraText.label.copyWith(color: c.textPrimary)),
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
