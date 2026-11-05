import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../home/home_screen.dart';
import '../order/address_editor.dart' show SheetPanel;
import 'tracking_map.dart';

/// Vitesse moyenne d'une moto dans Douala, pour une estimation prudente de l'arrivée.
const _metersPerMinute = 300.0;

/// Suivi d'une commande (F1) : carte (ondes pendant la recherche, moto qui avance), étape
/// en cours, livreur à appeler. Chaque étape s'annonce par un son ; à la livraison,
/// fanfare, confettis et récapitulatif à partager.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId, required this.onBack, this.now});

  final String orderId;
  final VoidCallback onBack;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _recap = GlobalKey();
  TrackedOrder? _order;
  String? _error;
  MapPoint? _rider;
  double? _heading;
  bool _celebrate = false;
  String? _pickupCode;
  bool _confirmCancel = false;
  bool _busy = false;
  StreamSubscription<RealtimeEvent>? _events;
  late final RealtimeClient _realtime;
  Timer? _refresh;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _realtime = ref.read(realtimeProvider)..connect();
    _events = _realtime.stream.listen(_onEvent);
    _realtime.subscribeOrder(widget.orderId, onAck: _onAck);
    // Temps réel coupé : l'étape est relue de temps en temps.
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _refresh?.cancel();
    _realtime.unsubscribeOrder(widget.orderId);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await ref.read(clientApiProvider).order(widget.orderId);
      if (!mounted) return;
      final before = _order?.status;
      setState(() {
        _order = order;
        _error = null;
      });
      if (before != null && before != order.status) _announce(order.status);
    } catch (error) {
      if (mounted && _order == null) setState(() => _error = errorMessage(context, error));
    }
  }

  void _onAck(Json ack) {
    final position = ack['position'];
    if (position is Map && mounted) _move(Map<String, Object?>.from(position));
  }

  void _move(Json position) {
    final latitude = (position['latitude'] as num?)?.toDouble();
    final longitude = (position['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    setState(() {
      _rider = MapPoint(latitude, longitude);
      _heading = (position['heading'] as num?)?.toDouble();
    });
  }

  void _onEvent(RealtimeEvent event) {
    if (event.payload['orderId'] != widget.orderId) return;
    switch (event.name) {
      case 'rider.position':
        _move(event.payload);
      case 'order.status':
        final status = event.payload['status'];
        final order = _order;
        if (status is String && order != null && status != order.status) {
          setState(() => _order = order.withStatus(status));
          _announce(status);
        }
        // Livreur, heures des étapes : relus.
        unawaited(_load());
    }
  }

  /// Chaque étape s'annonce : livreur trouvé, colis récupéré, livré (fanfare, confettis).
  void _announce(String status) {
    switch (status) {
      case 'ASSIGNED':
        TaraFeedback.play(context, TaraSound.received);
      case 'PICKED_UP':
        TaraFeedback.play(context, TaraSound.pickedUp);
      case 'DELIVERED':
        TaraFeedback.play(context, TaraSound.delivered);
        setState(() => _celebrate = true);
        ref
          ..invalidate(activeOrdersProvider)
          ..invalidate(walletProvider);
      case 'DELIVERY_FAILED':
        TaraFeedback.play(context, TaraSound.error);
    }
  }

  Future<void> _newPickupCode() async {
    setState(() => _busy = true);
    try {
      final code = await ref.read(clientApiProvider).newPickupCode(widget.orderId);
      if (mounted) setState(() => _pickupCode = code);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context);
    if (!_confirmCancel) {
      setState(() => _confirmCancel = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(clientApiProvider).cancelOrder(widget.orderId, l.cancelReasonSender);
      ref.invalidate(activeOrdersProvider);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirmCancel = false;
        });
      }
    }
  }

  /// Le récapitulatif part en image (WhatsApp, SMS…), avec une ligne de texte.
  Future<void> _share(TrackedOrder order) async {
    final l = AppLocalizations.of(context);
    final delivered = order.reachedAt('DELIVERED') ?? _now;
    final text = l.recapShareText(order.reference, order.recipientName, formatClock(delivered));
    Uint8List? png;
    try {
      final boundary = _recap.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      final image = await boundary?.toImage(pixelRatio: 3);
      final bytes = await image?.toByteData(format: ui.ImageByteFormat.png);
      png = bytes?.buffer.asUint8List();
    } catch (_) {
      // Image impossible : le texte part seul.
    }
    await ref.read(shareProvider)(text, png);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = _order;
    final height = MediaQuery.sizeOf(context).height;
    final delivered = order?.status == 'DELIVERED';
    final panel = height * (delivered ? .62 : .48);
    final top = MediaQuery.paddingOf(context).top + 72;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: TaraScreen(
        safeTop: false,
        safeBottom: false,
        background: Positioned.fill(
          child: order == null
              ? ColoredBox(color: c.mapGround)
              : TrackingMap(
                  pickup: MapPoint(order.pickup.latitude, order.pickup.longitude),
                  dropoff: MapPoint(order.dropoff.latitude, order.dropoff.longitude),
                  rider: _riderShown(order),
                  heading: _heading,
                  searching: order.status == 'SEARCHING_RIDER' && !_scheduledLater(order),
                  toDropoff: const ['PICKED_UP', 'IN_DELIVERY', 'DELIVERED'].contains(order.status),
                  framePadding: EdgeInsets.only(top: top, bottom: panel - 20),
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
                      const SizedBox(width: 10),
                      if (order != null)
                        GlassCard(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text(order.reference, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: panel,
              child: SheetPanel(
                child: order == null
                    ? Center(
                        child: _error == null
                            ? const GooLoader()
                            : Padding(padding: const EdgeInsets.all(24), child: ErrorLine(_error!)),
                      )
                    : _Panel(
                        order: order,
                        now: _now,
                        rider: _rider,
                        pickupCode: _pickupCode,
                        confirmCancel: _confirmCancel,
                        busy: _busy,
                        error: _error,
                        recapKey: _recap,
                        onNewPickupCode: () => unawaited(_newPickupCode()),
                        onCancel: () => unawaited(_cancel()),
                        onShare: () => unawaited(_share(order)),
                        onCall: (phone) => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
                      ),
              ),
            ),
            if (_celebrate) const Positioned.fill(child: Confetti()),
          ],
        ),
      ),
    );
  }

  /// La moto n'est montrée que pendant la course.
  MapPoint? _riderShown(TrackedOrder order) =>
      const ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'].contains(order.status) ? _rider : null;

  bool _scheduledLater(TrackedOrder order) => order.scheduledFor?.isAfter(_now) ?? false;
}

/// Panneau du bas : étape en cours, progression, livreur, destinataire, actions ; une fois
/// livré, le récapitulatif à partager.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.order,
    required this.now,
    required this.rider,
    required this.pickupCode,
    required this.confirmCancel,
    required this.busy,
    required this.error,
    required this.recapKey,
    required this.onNewPickupCode,
    required this.onCancel,
    required this.onShare,
    required this.onCall,
  });

  final TrackedOrder order;
  final DateTime now;
  final MapPoint? rider;
  final String? pickupCode;
  final bool confirmCancel;
  final bool busy;
  final String? error;
  final GlobalKey recapKey;
  final VoidCallback onNewPickupCode;
  final VoidCallback onCancel;
  final VoidCallback onShare;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final recipientFirst = o.recipientName.trim().split(RegExp(r'\s+')).first;
    final riderName = o.rider?.name ?? '';
    final pickedUpAt = o.reachedAt('PICKED_UP');
    final deliveredAt = o.reachedAt('DELIVERED');
    final scheduled = o.scheduledFor != null && o.scheduledFor!.isAfter(now);
    final (title, body) = switch (o.status) {
      'CREATED' => (l.trackAwaitingPayment, l.trackAwaitingPaymentBody),
      _ when scheduled && const ['CREATED', 'SEARCHING_RIDER'].contains(o.status) => (
        l.trackScheduled,
        l.scheduledPickup(formatClock(o.scheduledFor!)),
      ),
      'SEARCHING_RIDER' => (l.trackSearching, l.trackSearchingBody),
      'ASSIGNED' => (l.trackAssigned(riderName), l.trackAssignedBody),
      'PICKED_UP' ||
      'IN_DELIVERY' => (l.trackOnTheWay(recipientFirst), l.trackOnTheWayBody(formatClock(pickedUpAt ?? now))),
      'DELIVERY_FAILED' => (l.trackFailed, l.trackFailedBody),
      'DELIVERED' => (l.trackDelivered, l.trackDeliveredBody(recipientFirst, formatClock(deliveredAt ?? now))),
      'RETURNED' => (l.trackReturned, ''),
      _ => (l.trackCancelled, ''),
    };
    final eta = _eta(o);
    final delivered = o.status == 'DELIVERED';
    final content = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, style: TaraText.titlePanel.copyWith(color: c.textPrimary)),
            ),
          ),
          if (eta != null) ...[const SizedBox(width: 10), InfoPill(label: l.trackEta(eta), icon: TaraIcons.clock)],
        ],
      ),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(body, style: TaraText.label.copyWith(color: c.textSecondary)),
      ],
      const SizedBox(height: 16),
      _Steps(order: o),
      const SizedBox(height: 16),
      if (delivered)
        RepaintBoundary(
          key: recapKey,
          child: _Recap(order: o),
        )
      else ...[
        if (o.rider case final rider? when rider.phone != null) ...[
          _RiderCard(rider: rider, onCall: () => onCall(rider.phone!)),
          const SizedBox(height: 10),
        ],
        ListRow(
          leading: const IconTile(icon: TaraIcons.mapPin, size: 40),
          title: l.forRecipient(o.recipientName),
          subtitle: o.dropoff.summary,
        ),
        if (pickupCode != null) ...[
          const SizedBox(height: 8),
          TintBox(
            tone: TintTone.accent,
            child: Text(
              l.pickupCodeShown(pickupCode!.split('').join(' ')),
              style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        if (const ['SEARCHING_RIDER', 'ASSIGNED'].contains(o.status) && pickupCode == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.newPickupCode, onPressed: busy ? null : onNewPickupCode),
          ),
        if (const ['CREATED', 'SEARCHING_RIDER'].contains(o.status)) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.cancelDelivery, onPressed: busy ? null : onCancel),
          ),
          if (confirmCancel) Text(l.cancelConfirm, style: TaraText.small.copyWith(color: c.dangerText)),
        ],
      ],
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    // Un bouton seulement une fois livré (« Partager ») : sinon, pas de socle vide.
    if (delivered) {
      return ScrollWithFooter(
        horizontal: 20,
        top: 4,
        content: content,
        footer: PrimaryButton(label: l.shareRecap, icon: TaraIcons.send, onPressed: onShare),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
    );
  }

  /// Arrivée estimée (prudente) du livreur à l'étape visée, en minutes.
  int? _eta(TrackedOrder o) {
    final position = rider;
    if (position == null) return null;
    final target = switch (o.status) {
      'ASSIGNED' => o.pickup,
      'PICKED_UP' || 'IN_DELIVERY' => o.dropoff,
      _ => null,
    };
    if (target == null) return null;
    final meters = _distance(position, MapPoint(target.latitude, target.longitude));
    return math.max(1, (meters / _metersPerMinute).ceil());
  }

  static double _distance(MapPoint a, MapPoint b) {
    const earth = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.sqrt(h));
  }
}

/// Les quatre étapes : commande, livreur, colis récupéré, livré, avec leur heure.
class _Steps extends StatelessWidget {
  const _Steps({required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final steps = [
      (l.stepOrdered, order.createdAt),
      (l.stepRiderFound, order.reachedAt('ASSIGNED')),
      (l.stepPickedUp, order.reachedAt('PICKED_UP')),
      (l.stepDelivered, order.reachedAt('DELIVERED')),
    ];
    final done = steps.lastIndexWhere((step) => step.$2 != null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, at)) in steps.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(height: 3, color: i <= done ? TaraBrand.orange : c.track),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: i <= done ? TaraBrand.gradient : null,
                        color: i <= done ? null : c.track,
                        border: i == done + 1 ? Border.all(color: TaraBrand.orange, width: 2) : null,
                      ),
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox.shrink()
                          : Container(height: 3, color: i < done ? TaraBrand.orange : c.track),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.small.copyWith(
                    color: i <= done ? c.textPrimary : c.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  at == null ? ' ' : formatClock(at),
                  style: TaraText.small.copyWith(color: c.textTertiary, fontFeatures: TaraText.tabular),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Le livreur : initiales, prénom, véhicule et plaque, bouton d'appel.
class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.onCall});

  final OrderRider rider;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final vehicle = switch (rider.vehicleType) {
      'CAR' => l.vehicleCar,
      'TRICYCLE' => l.vehicleTricycle,
      _ => l.vehicleMotorbike,
    };
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          InitialsAvatar(name: rider.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
                Text([vehicle, ?rider.plateNumber].join(' · '), style: TaraText.small.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          GlassIconButton(icon: TaraIcons.phone, label: l.callRider(rider.name), onPressed: onCall),
        ],
      ),
    );
  }
}

/// Récapitulatif d'une livraison réussie, partagé en image : marque, destinataire, heure,
/// durée, livreur, montant encaissé.
class _Recap extends StatelessWidget {
  const _Recap({required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final delivered = o.reachedAt('DELIVERED');
    final started = o.reachedAt('PICKED_UP') ?? o.createdAt;
    final minutes = delivered == null ? null : math.max(1, delivered.difference(started).inMinutes);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: TaraBrand.gradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                const TaraIcon(TaraIcons.check, size: 24, strokeWidth: 2.6, color: TaraBrand.onBrand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.trackDelivered, style: TaraText.cardTitle.copyWith(color: TaraBrand.onBrand)),
                ),
                Text('Tara', style: TaraText.cardTitle.copyWith(color: TaraBrand.onBrand)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.recipientName,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                ),
                Text(o.dropoff.summary, style: TaraText.small.copyWith(color: c.textSecondary)),
                const SizedBox(height: 10),
                Text(
                  [
                    if (delivered != null) formatClock(delivered),
                    if (minutes != null) l.deliveredIn(minutes),
                    if (o.rider != null) l.deliveredBy(o.rider!.name),
                  ].join(' · '),
                  style: TaraText.label.copyWith(color: c.textPrimary),
                ),
                if (o.codAmount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.collectedAmount('${formatAmount(o.codAmount)} F'),
                    style: TaraText.label.copyWith(color: c.success, fontWeight: FontWeight.w800),
                  ),
                ],
                const SizedBox(height: 6),
                Text(o.reference, style: TaraText.small.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
