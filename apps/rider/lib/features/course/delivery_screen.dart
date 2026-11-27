import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../map/tara_map.dart';
import 'address_help.dart';
import 'course_page.dart';
import 'course_scaffold.dart';
import 'order_chat.dart';

/// Au-delà, le livreur est prévenu que sa livraison sera signalée au support.
const farFromAddressMeters = 200;

/// Arrivé : à moins de cette distance de l'adresse.
const arrivedMeters = 150;

/// 09 · Livraison : itinéraire jusqu'au client, argent à encaisser à la remise, code du
/// destinataire ou livraison sans code (nom de la personne qui reçoit, le support appelle le
/// client), photo de remise. Avec de l'argent à encaisser, l'encaissement (12) vient avant
/// l'envoi de la livraison (décision : encaisser puis livrer).
class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onDelivered,
    required this.onCollect,
    required this.onFailure,
    this.tourProgress,
    this.now,
  });

  final RiderOrder order;

  /// Tournée (2c) : arrêt en cours, nombre d'arrêts et ce qui est déjà gagné.
  final ({int stop, int total, int earned})? tourProgress;
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Livraison envoyée (sent) ou gardée sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onDelivered;

  /// Argent à encaisser d'abord : ouvre l'encaissement (12) avec la livraison préparée.
  final void Function(DeliveryDraft draft) onCollect;

  /// « Livraison impossible ? » : écran d'échec (10).
  final VoidCallback onFailure;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final _code = TextEditingController();
  final _receivedBy = TextEditingController();
  bool _withCode = true;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  /// « Je suis arrivé » touché : code et photo s'affichent (sinon, dès 150 m de l'adresse).
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    void clearError() => setState(() => _error = null);
    _code.addListener(clearError);
    _receivedBy.addListener(clearError);
    // Livraison refusée restée dans la file (code faux saisi hors réseau) : on la reprend.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'deliver');
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
      _withCode = refused.body.containsKey('deliveryCode');
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _receivedBy.dispose();
    super.dispose();
  }

  bool get _ready => _photoPath != null && (_withCode ? _code.text.length == 4 : _receivedBy.text.trim().length >= 2);

  Future<void> _takePhoto() async {
    final path = await ref.read(takeProofPhotoProvider)();
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      _photoAt = widget.now?.call() ?? DateTime.now();
      _error = null;
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final photo = _photoPath;
    if (photo == null || !_ready) return;
    // Argent à encaisser : l'encaissement d'abord, la livraison partira ensuite.
    if (widget.order.collectAtDelivery > 0) {
      widget.onCollect(
        DeliveryDraft(
          photoPath: photo,
          code: _withCode ? _code.text : null,
          receivedBy: _withCode ? null : _receivedBy.text.trim(),
          retryActionId: _refusedActionId,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(courseActionsProvider);
    final at = await actions.position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _busy = false;
        _error = l.noPositionYet;
      });
      return;
    }
    final result = await actions.deliver(
      widget.order,
      code: _withCode ? _code.text : null,
      receivedBy: _withCode ? null : _receivedBy.text.trim(),
      photoPath: photo,
      at: at,
      retryActionId: _refusedActionId,
    );
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
        _code.clear();
      });
      TaraFeedback.play(context, TaraSound.error);
      return;
    }
    TaraFeedback.play(context, TaraSound.delivered);
    widget.onDelivered(result.outcome);
  }

  void _toggleMode() => setState(() {
    _withCode = !_withCode;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final due = order.collectAtDelivery > 0;
    final name = order.recipient.name ?? order.dropoff.contactName ?? order.reference;
    final phone = order.recipient.phone ?? order.dropoff.contactPhone;
    final online = ref.watch(onlineControllerProvider);
    final here = online.lastPosition;
    final meters = here == null
        ? null
        : courseDistance(here.latitude, here.longitude, order.dropoff.latitude, order.dropoff.longitude);
    final stop = MapStop(
      latitude: order.dropoff.latitude,
      longitude: order.dropoff.longitude,
      dropoff: true,
      label: name,
    );
    // Noté dans le journal d'appels : preuve d'appel en cas d'échec (10).
    final VoidCallback? call = phone == null
        ? null
        : () => ref.read(callJournalProvider).call(order.id, to: 'RECIPIENT', phone: phone);
    final kicker = '${l.stepDelivery} · ${order.reference}';
    final collect = due
        ? CollectBox(amount: order.collectAtDelivery, title: l.collectAtDeliveryTitle, body: l.collectAtDeliveryBody)
        : null;

    // En route (maquette Livreur-En-Route) : tant qu'il est loin et n'a pas dit être arrivé.
    if (!_arrived && meters != null && meters > arrivedMeters) {
      return _EnRoute(
        order: order,
        name: name,
        kicker: kicker,
        stop: stop,
        meters: meters,
        tourProgress: widget.tourProgress,
        onSos: widget.onSos,
        onBack: widget.onBack,
        onCall: call,
        collect: collect,
        onArrived: () => setState(() => _arrived = true),
        onFailure: _busy ? null : widget.onFailure,
        now: widget.now?.call() ?? DateTime.now(),
      );
    }

    return CoursePage(
      stop: stop,
      header: CourseHeader(
        kicker: kicker,
        title: name,
        subtitle: order.dropoff.line,
        onBack: widget.onBack,
        onSos: widget.onSos,
        callLabel: l.callPerson(name),
        onCall: call,
        messageLabel: l.chatWithSender(order.sender.name ?? order.reference),
        unread: ref.watch(chatInboxProvider).unread(order.id),
        onMessage: () => unawaited(openOrderChat(context, ref, order)),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Livraison définitive : on glisse plutôt que toucher, pour éviter l'erreur.
          SwipeButton(
            plain: true,
            height: 62,
            label: l.slideConfirmDelivery,
            semanticLabel: l.confirmDelivery,
            loading: _busy,
            onConfirmed: _ready ? _submit : null,
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : widget.onFailure,
              child: Text(
                l.cantDeliverShort,
                style: TaraText.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary.withValues(alpha: .72),
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        if (widget.tourProgress case final tour?)
          Center(
            child: InfoPill(
              label: l.tourProgress(tour.stop, tour.total, '${formatAmount(tour.earned)} F'),
              icon: TaraIcons.package,
              tone: TintTone.accent,
            ),
          ),
        CourseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TaraIcon(TaraIcons.mapPin, size: 20, color: c.accentText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.dropoff.line,
                      style: TaraText.text.copyWith(fontSize: 13, height: 1.4, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
              AddressHelp(orderId: order.id, stop: 'dropoff', address: order.dropoff, name: name),
            ],
          ),
        ),
        // Deux colis à bord : le numéro dit lequel remettre ici.
        if (order.batchNumber != null) ParcelCard(order: order, title: l.parcelToDeliver, showRecipient: false),
        ?collect,
        // Loin de l'adresse : la livraison confirmée d'ici sera signalée au support.
        if (meters != null && meters > farFromAddressMeters)
          CourseWarning(l.farFromAddress(formatDistance(meters.round()))),
        if (order.dropoff.motorbikeRestricted) CourseWarning(l.noMotoAddress),
        CourseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_withCode) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        l.deliveryCodeLabel,
                        style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary),
                      ),
                    ),
                    Text(
                      l.deliveryCodeHint,
                      style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .66)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CodeCells(length: 4, controller: _code, cellHeight: 52, autofocus: false, digitLabel: l.digitLabel),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TaraLink(label: l.noCodeLink, onPressed: _busy ? null : _toggleMode),
                ),
              ] else ...[
                Text(l.noCodeTitle, style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  l.noCodeBody,
                  style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .72)),
                ),
                const SizedBox(height: 10),
                TaraTextField(
                  label: l.receivedByLabel,
                  hint: l.receivedByHint,
                  controller: _receivedBy,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TaraLink(label: l.hasCodeLink, onPressed: _busy ? null : _toggleMode),
                ),
              ],
            ],
          ),
        ),
        PhotoCard(
          taken: _photoPath != null,
          takenAt: _photoAt,
          title: l.photoHandover,
          takenTitle: l.photoHandoverTaken,
          hint: l.photoHandoverHint,
          onTake: _busy ? null : _takePhoto,
        ),
        if (_error != null) ErrorLine(_error!),
      ],
    );
  }
}

/// En route vers le client (maquette Livreur-En-Route) : carte plein écran, bandeau de
/// distance en haut avec le SOS, panneau du bas (client, adresse, aide, montant à
/// encaisser), « Je suis arrivé » et « Livraison impossible ».
class _EnRoute extends ConsumerWidget {
  const _EnRoute({
    required this.order,
    required this.name,
    required this.kicker,
    required this.stop,
    required this.meters,
    required this.tourProgress,
    required this.onSos,
    required this.onBack,
    required this.onCall,
    required this.collect,
    required this.onArrived,
    required this.onFailure,
    required this.now,
  });

  final DateTime now;
  final RiderOrder order;
  final String name;
  final String kicker;
  final MapStop stop;
  final double meters;
  final ({int stop, int total, int earned})? tourProgress;
  final VoidCallback onSos;
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final Widget? collect;
  final VoidCallback onArrived;
  final VoidCallback? onFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final online = ref.watch(onlineControllerProvider);
    final insets = MediaQuery.paddingOf(context);
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final sheet = c.isDark ? const Color(0xFF16161E) : const Color(0xFFFFFFFF);
    return Material(
      color: c.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: online,
              builder: (context, _) => TaraMap(
                rider: online.lastPosition,
                stop: stop,
                framePadding: EdgeInsets.fromLTRB(50, 110 + insets.top, 50, 360),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l.back,
                      child: GestureDetector(
                        onTap: onBack,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: sheet.withValues(alpha: .94),
                            border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: TaraBrand.gradient,
                                ),
                                alignment: Alignment.center,
                                child: const TaraIcon(
                                  TaraIcons.navigation,
                                  size: 22,
                                  strokeWidth: 2.2,
                                  color: Color(0xFF140800),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.distanceAway(formatDistance(meters.round())),
                                      style: TextStyle(
                                        fontFamily: TaraText.sora,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      l.towards(order.dropoff.neighborhood ?? order.dropoff.city),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TaraText.small.copyWith(
                                        fontSize: 12,
                                        color: c.textPrimary.withValues(alpha: .72),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SosButton(label: l.safetyAlert, onPressed: onSos, size: 48, round: true),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16 + insets.bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arrivée estimée (maquette) : minutes, distance, heure, au-dessus de la fiche.
                _EtaPill(meters: meters, now: now),
                const SizedBox(height: 12),
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .56),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: sheet,
                    border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (tourProgress case final tour?) ...[
                          InfoPill(
                            label: l.tourProgress(tour.stop, tour.total, '${formatAmount(tour.earned)} F'),
                            icon: TaraIcons.package,
                            tone: TintTone.accent,
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    kicker.toUpperCase(),
                                    style: TaraText.small.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: c.accentText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontFamily: TaraText.sora,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.dropoff.line,
                                    style: TaraText.text.copyWith(
                                      fontSize: 13,
                                      color: c.textPrimary.withValues(alpha: .78),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onCall != null) ...[
                              const SizedBox(width: 12),
                              Semantics(
                                button: true,
                                label: l.callPerson(name),
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: onCall,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.textPrimary.withValues(alpha: .08),
                                      border: Border.all(color: c.textPrimary.withValues(alpha: .14)),
                                    ),
                                    alignment: Alignment.center,
                                    child: TaraIcon(TaraIcons.phone, size: 20, color: ok),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        AddressHelp(
                          orderId: order.id,
                          stop: 'dropoff',
                          address: order.dropoff,
                          name: name,
                          tiles: true,
                        ),
                        if (collect != null) ...[const SizedBox(height: 12), collect!],
                        const SizedBox(height: 12),
                        PrimaryButton(label: l.arrivedAction, height: 56, strong: true, onPressed: onArrived),
                        Center(
                          child: TextButton(
                            onPressed: onFailure,
                            child: Text(
                              l.cantDeliverShort,
                              style: TaraText.label.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary.withValues(alpha: .72),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « 12 min · 4,1 km · arrivée 15:24 » : à une allure prudente de moto dans Douala.
class _EtaPill extends StatelessWidget {
  const _EtaPill({required this.meters, required this.now});

  final double meters;
  final DateTime now;

  /// Même allure que l'app expéditeur et le serveur (300 m par minute).
  static const metersPerMinute = 300;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final minutes = (meters / metersPerMinute).ceil().clamp(1, 600);
    final arrival = now.add(Duration(minutes: minutes));
    final time = '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.bg.withValues(alpha: .86),
        border: Border.all(color: c.textPrimary.withValues(alpha: .14)),
      ),
      child: Text(
        l.enRouteEta(minutes, formatDistance(meters.round()), time),
        style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary),
      ),
    );
  }
}
