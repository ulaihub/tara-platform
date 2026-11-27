import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../map/tara_map.dart';
import 'address_help.dart';
import 'course_page.dart';
import 'course_scaffold.dart';
import 'order_chat.dart';
import 'scan_code_screen.dart';

/// 08 · Enlèvement : itinéraire jusqu'au vendeur, montant à encaisser sur place, code de
/// l'expéditeur et photo du colis. « Colis récupéré » passe par la file hors connexion.
/// « Colis non conforme ? » ouvre le refus du colis (trop grand, trop lourd, interdit…).
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onPickedUp,
    required this.onRefuse,
    this.onSenderAbsent,
    this.tour = const [],
    this.now,
  });

  final RiderOrder order;

  /// Retour à l'accueil, la course reste en cours.
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis récupéré : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onPickedUp;

  /// « Colis non conforme ? » : écran de refus du colis.
  final VoidCallback onRefuse;

  /// Parti sans le colis : l'expéditeur n'est pas venu après l'attente maximale (D).
  final VoidCallback? onSenderAbsent;

  /// Tournée (2c) : tous les colis à récupérer ici, dans l'ordre des arrêts ; vide sinon.
  final List<RiderOrder> tour;

  bool get isTour => tour.length > 1;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  final _code = TextEditingController();
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  /// Code lu par la caméra (QR de l'expéditeur) ou en train d'être tapé.
  bool _scanned = false;
  bool _typing = false;

  /// QR du code d'enlèvement (maquette Scanner) : il doit être celui de cette course (ou d'un
  /// colis de la tournée) ; le code lu remplit les 4 chiffres.
  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final orders = widget.isTour ? widget.tour : [order];
    final shop = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final numbers = [for (final o in orders) ?o.batchNumber];
    final code = await Navigator.of(context).push<String>(
      scopedPage(
        context,
        (_) => ScanCodeScreen(
          references: [for (final o in orders) o.reference],
          context: numbers.length > 1 ? '$shop · ${l.scanParcels(_list(l, numbers))}' : '$shop · ${order.reference}',
          parcels: orders.length,
        ),
      ),
    );
    if (!mounted) return;
    if (code == null) {
      // Retour sans code (ou « Taper les 4 chiffres ») : on tape.
      if (_code.text.length != 4) setState(() => _typing = true);
      return;
    }
    setState(() {
      _code.text = code;
      _scanned = true;
      _typing = false;
      _error = null;
    });
  }

  static String _list(AppLocalizations l, List<int> numbers) => numbers.length == 1
      ? '${numbers.single}'
      : l.listAnd(numbers.take(numbers.length - 1).join(', '), '${numbers.last}');

  /// Tournée : colis cochés un à un par le livreur, en les prenant.
  final Set<String> _checked = {};

  String get _pickupKind => widget.isTour ? CourseActions.tourPickupKind : 'pickup';

  /// Arrivée signalée au point d'enlèvement : l'attente compte depuis là (D).
  late DateTime? _arrivedAt = widget.order.arrivedPickupAt;
  bool _arriving = false;
  bool _confirmLeave = false;
  bool _leaving = false;
  Timer? _tick;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    // Code déjà tapé (écran rouvert après un refus) : les cases restent ouvertes.
    _typing = _code.text.isNotEmpty;
    if (_arrivedAt != null) _startTick();
    // Enlèvement refusé resté dans la file (écran rouvert) : on reprend où il en était.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, _pickupKind);
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Le temps d'attente affiché avance toute seule.
  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  /// L'expéditeur ne vient pas (D) : après l'attente maximale, sur place, après 2 appels. Le
  /// premier toucher annonce ce qu'il paiera ; le second annule la course.
  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    if (!_confirmLeave) {
      setState(() => _confirmLeave = true);
      return;
    }
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      final at = await ref.read(courseActionsProvider).position();
      if (!mounted) return;
      if (at == null) {
        setState(() => _error = l.noPositionYet);
        return;
      }
      await ref
          .read(riderApiProvider)
          .senderAbsent(
            widget.order.id,
            latitude: at.latitude,
            longitude: at.longitude,
            callLog: [for (final call in ref.read(callJournalProvider).forOrder(widget.order.id)) call.toApi()],
          );
      await ref.read(courseActionsProvider).activeOrder.update(widget.order.withStatus('CANCELLED'));
      widget.onSenderAbsent?.call();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) {
        setState(() {
          _leaving = false;
          _confirmLeave = false;
        });
      }
    }
  }

  /// « Je suis arrivé » : sur place seulement (le serveur vérifie la position).
  Future<void> _arrive() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _arriving = true;
      _error = null;
    });
    try {
      final at = await ref.read(courseActionsProvider).position();
      if (!mounted) return;
      if (at == null) {
        setState(() => _error = l.noPositionYet);
        return;
      }
      final updated = await ref
          .read(riderApiProvider)
          .arrived(widget.order.id, latitude: at.latitude, longitude: at.longitude);
      if (!mounted) return;
      setState(() => _arrivedAt = updated.arrivedPickupAt ?? _now());
      _startTick();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
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

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final photo = _photoPath;
    if (photo == null || _code.text.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final at = await ref.read(courseActionsProvider).position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _busy = false;
        _error = l.noPositionYet;
      });
      return;
    }
    final actions = ref.read(courseActionsProvider);
    final result = widget.isTour
        ? await actions.pickUpTour(
            widget.tour,
            code: _code.text,
            photoPath: photo,
            at: at,
            retryActionId: _refusedActionId,
          )
        : await actions.pickUp(
            widget.order,
            code: _code.text,
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
    TaraFeedback.play(context, TaraSound.pickedUp);
    widget.onPickedUp(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final phone = order.sender.phone ?? order.pickup.contactPhone;
    final hasCode = _code.text.length == 4;
    final allChecked = !widget.isTour || _checked.length == widget.tour.length;
    final ready = _photoPath != null && hasCode && allChecked;
    final here = ref.watch(onlineControllerProvider).lastPosition;
    final distance = here == null
        ? null
        : courseDistance(here.latitude, here.longitude, order.pickup.latitude, order.pickup.longitude);
    final missing = [
      if (_photoPath == null) l.missingPhoto,
      if (!hasCode) l.missingCode,
      if (!allChecked) l.missingParcels,
    ];
    final accent2 = c.isDark ? const Color(0xFFFFC283) : const Color(0xFF9A3412);

    return CoursePage(
      stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
      header: CourseHeader(
        kicker: distance == null ? l.stepPickup : '${l.stepPickup} · ${formatDistance(distance.round())}',
        title: senderName,
        subtitle: [
          if (order.pickup.contactName case final contact? when contact != senderName) contact,
          order.reference,
        ].join(' · '),
        onBack: widget.onBack,
        onSos: widget.onSos,
        callLabel: l.callPerson(senderName),
        // Appels gardés dans le journal : ils prouvent l'attente si l'expéditeur ne vient pas.
        onCall: phone == null ? null : () => ref.read(callJournalProvider).call(order.id, to: 'SENDER', phone: phone),
        messageLabel: l.chatWithSender(senderName),
        unread: ref.watch(chatInboxProvider).unread(order.id),
        onMessage: () => unawaited(openOrderChat(context, ref, order)),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enlèvement définitif : on glisse plutôt que toucher, pour éviter l'erreur.
          SwipeButton(
            plain: true,
            height: 62,
            label: l.slideParcelCollected,
            semanticLabel: l.parcelCollected,
            loading: _busy,
            onConfirmed: ready ? _submit : null,
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.missingItems(missing.join(', ')),
              textAlign: TextAlign.center,
              style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .62)),
            ),
          ],
        ],
      ),
      children: [
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
                      order.pickup.line,
                      style: TaraText.text.copyWith(fontSize: 13, height: 1.4, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
              if (order.instructions case final note? when note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '« $note »',
                  style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .70)),
                ),
              ],
              AddressHelp(orderId: order.id, stop: 'pickup', address: order.pickup, name: senderName),
            ],
          ),
        ),
        _WaitingBox(
          arrivedAt: _arrivedAt,
          rules: ref.watch(riderConfigProvider).value?.waiting ?? const WaitingRules(),
          now: _now(),
          busy: _arriving,
          onArrive: _busy ? null : _arrive,
          senderCalls: _arrivedAt == null
              ? 0
              : ref
                    .watch(callJournalProvider)
                    .forOrder(order.id)
                    .where((call) => call.to == 'SENDER' && !call.at.isBefore(_arrivedAt!))
                    .length,
          confirmLeave: _confirmLeave,
          leaving: _leaving,
          onLeave: _busy ? null : _leave,
        ),
        PhotoCard(
          taken: _photoPath != null,
          takenAt: _photoAt,
          title: l.photoParcel,
          takenTitle: l.photoParcelTaken,
          hint: widget.isTour
              ? l.photoTourHint(widget.tour.length)
              : switch (order.batchNumber) {
                  final number? => l.photoParcelHintNumber(number),
                  null => l.photoParcelHint,
                },
          onTake: _busy ? null : _takePhoto,
        ),
        // Quel colis prendre : l'expéditeur peut en avoir plusieurs, pour d'autres livreurs.
        if (widget.isTour)
          _TourChecklist(
            tour: widget.tour,
            checked: _checked,
            onToggle: _busy
                ? null
                : (id) => setState(() => _checked.contains(id) ? _checked.remove(id) : _checked.add(id)),
          )
        else
          ParcelCard(order: order, title: l.parcelToCollect),
        if (order.collectAtPickup > 0)
          CollectBox(amount: order.collectAtPickup, title: l.collectAtPickupTitle, body: l.collectAtPickupBody),
        if (order.bulky)
          CourseCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaraIcon(TaraIcons.package, size: 18, color: c.accentText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.loadingHelp ? l.bulkyWithHelpNotice : l.bulkyNotice,
                    style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (order.pickup.motorbikeRestricted) CourseWarning(l.noMotoAddress),
        _PickupCodeCard(
          code: hasCode ? _code.text : null,
          scanned: _scanned,
          typing: _typing,
          controller: _code,
          onScan: _busy ? null : _scan,
          onType: _busy ? null : () => setState(() => _typing = true),
          onChange: _busy
              ? null
              : () => setState(() {
                  _code.clear();
                  _scanned = false;
                  _typing = false;
                }),
        ),
        if (_error != null) ErrorLine(_error!),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          children: [
            TextButton(
              onPressed: _busy ? null : widget.onRefuse,
              child: Text(
                l.parcelNonConforming,
                style: TaraText.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent2,
                  decoration: TextDecoration.underline,
                  decorationColor: accent2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Attente chez l'expéditeur (D) : « Je suis arrivé » démarre le temps ; au-delà des minutes
/// gratuites, l'expéditeur paie et le livreur reçoit sa part.
class _WaitingBox extends StatelessWidget {
  const _WaitingBox({
    required this.arrivedAt,
    required this.rules,
    required this.now,
    required this.busy,
    required this.onArrive,
    this.senderCalls = 0,
    this.confirmLeave = false,
    this.leaving = false,
    this.onLeave,
  });

  final DateTime? arrivedAt;
  final WaitingRules rules;
  final DateTime now;
  final bool busy;
  final VoidCallback? onArrive;

  /// Appels à l'expéditeur depuis l'arrivée, et le départ sans le colis (D).
  final int senderCalls;
  final bool confirmLeave;
  final bool leaving;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    String f(int amount) => '${formatAmount(amount)}\u00a0F';
    final since = arrivedAt;
    if (since == null) {
      return CourseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.waitingRule(
                rules.freeMinutes,
                f(rules.feePerStep),
                rules.stepMinutes,
                f(rules.riderPart(rules.feePerStep)),
                f(rules.maxFee),
              ),
              style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: busy ? l.arrivedSending : l.arrivedAction,
              icon: TaraIcons.mapPin,
              height: 48,
              strong: true,
              onPressed: busy ? null : onArrive,
            ),
          ],
        ),
      );
    }
    final waited = now.difference(since);
    final minutes = waited.inMinutes;
    final fee = rules.feeAfter(waited);
    final canLeave = minutes >= rules.maxMinutes;
    final callsLeft = WaitingRules.absentMinCalls - senderCalls;
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final free = rules.freeMinutes - minutes < 0 ? 0 : rules.freeMinutes - minutes;
    return CourseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Minutes d'attente dans un rond où le liquide monte avec le temps.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color.fromRGBO(255, 177, 92, .45), width: 2),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipOval(
                      child: LiquidFill(
                        level: (minutes / rules.maxMinutes).clamp(.15, 1.0),
                        amplitude: 3,
                        front: TaraLiquid.front,
                        back: TaraLiquid.back(dark: c.isDark),
                        frontPeriod: TaraLiquid.frontPeriod,
                        backPeriod: TaraLiquid.backPeriod,
                      ),
                    ),
                    Center(
                      child: Text(
                        '$minutes′',
                        style: TaraText.label.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFFFFF),
                          shadows: const [Shadow(color: Color.fromRGBO(0, 0, 0, .6), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: fee == 0
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: l.waitingSince(minutes)),
                            TextSpan(
                              text: l.waitingFreeLeft(free),
                              style: TextStyle(color: ok, fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: l.waitingThen(f(rules.feePerStep), rules.stepMinutes)),
                          ],
                        ),
                        style: TaraText.text.copyWith(fontSize: 13, color: c.textPrimary, height: 1.4),
                      )
                    : Text(
                        l.waitingPaid(minutes, f(fee), f(rules.riderPart(fee))),
                        style: TaraText.text.copyWith(fontSize: 13, color: c.textPrimary, height: 1.4),
                      ),
              ),
            ],
          ),
          if (!canLeave) ...[
            const SizedBox(height: 6),
            Text(
              l.senderAbsentLater(rules.maxMinutes - minutes, f(rules.absentRiderPart)),
              style: TaraText.small.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: 10),
            if (callsLeft > 0)
              Text(l.senderAbsentCallFirst(callsLeft), style: TaraText.small.copyWith(color: c.textSecondary))
            else if (confirmLeave)
              Text(
                l.senderAbsentConfirm(f(rules.absentFee), f(rules.absentRiderPart)),
                style: TaraText.small.copyWith(color: c.dangerText, height: 1.4),
              ),
            const SizedBox(height: 6),
            GlassButton(
              label: leaving ? l.arrivedSending : l.senderAbsentAction,
              icon: TaraIcons.close,
              onPressed: callsLeft > 0 || leaving ? null : onLeave,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tournée (2c) : chaque colis à récupérer, coché par le livreur en le prenant.
class _TourChecklist extends StatelessWidget {
  const _TourChecklist({required this.tour, required this.checked, required this.onToggle});

  final List<RiderOrder> tour;
  final Set<String> checked;
  final void Function(String orderId)? onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return CourseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.tourToCollect(checked.length, tour.length).toUpperCase(),
            style: TaraText.small.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: c.accentText,
            ),
          ),
          const SizedBox(height: 4),
          for (final order in tour)
            Semantics(
              button: true,
              toggled: checked.contains(order.id),
              child: InkWell(
                onTap: onToggle == null ? null : () => onToggle!(order.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: checked.contains(order.id) ? TaraBrand.gradient : null,
                          border: Border.all(
                            color: checked.contains(order.id)
                                ? const Color(0xFFFF8A00)
                                : c.textPrimary.withValues(alpha: .35),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: checked.contains(order.id)
                            ? const TaraIcon(TaraIcons.check, size: 15, strokeWidth: 3, color: Color(0xFF140800))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      if (order.batchNumber != null)
                        SizedBox(
                          width: 44,
                          child: Text(
                            l.parcelNumberShort(order.batchNumber!),
                            style: TaraText.label.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '${parcelForWhom(l, order)} · ${parcelWhat(l, order)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TaraText.text.copyWith(fontSize: 13, color: c.textPrimary.withValues(alpha: .8)),
                        ),
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

/// Code d'enlèvement (maquette) : « Scanner » le QR de l'expéditeur ou « Taper 4 chiffres » ;
/// une fois le code là, ses chiffres en vert (« Code vérifié » s'il a été scanné).
class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({
    required this.code,
    required this.scanned,
    required this.typing,
    required this.controller,
    required this.onScan,
    required this.onType,
    required this.onChange,
  });

  final String? code;
  final bool scanned;
  final bool typing;
  final TextEditingController controller;
  final VoidCallback? onScan;
  final VoidCallback? onType;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final Widget body;
    if (code case final value? when !typing || scanned) {
      body = Row(
        children: [
          for (final digit in value.split('')) ...[
            Container(
              width: 34,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(74, 222, 155, .14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color.fromRGBO(74, 222, 155, .4)),
              ),
              child: Text(digit, style: TaraText.titlePanel.copyWith(fontSize: 18, color: c.textPrimary)),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          TaraIcon(TaraIcons.check, size: 16, strokeWidth: 2.6, color: ok),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              scanned ? l.pickupCodeScanned : l.pickupCodeTyped,
              style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: ok),
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l.pickupCodeChange)),
        ],
      );
    } else if (typing) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodeCells(length: 4, controller: controller, cellHeight: 52, digitLabel: l.digitLabel),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onScan,
              icon: TaraIcon(TaraIcons.scan, size: 16, color: c.accentText),
              label: Text(l.pickupScan),
            ),
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onScan,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const TaraIcon(TaraIcons.scan, size: 18, color: TaraBrand.onBrand),
                        const SizedBox(width: 6),
                        Text(
                          l.pickupScan,
                          style: TaraText.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: TaraBrand.onBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onType,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: c.textPrimary,
                backgroundColor: c.textPrimary.withValues(alpha: .06),
                side: BorderSide(color: c.textPrimary.withValues(alpha: .16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: TaraIcon(TaraIcons.keypad, size: 16, color: c.textPrimary),
              label: Text(
                l.pickupTypeDigits,
                style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
            ),
          ),
        ],
      );
    }
    return CourseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l.pickupCodeLabel, style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary)),
              ),
              Text(
                l.pickupCodeHint,
                style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .66)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}
