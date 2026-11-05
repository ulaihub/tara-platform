import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
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
import 'course_scaffold.dart';
import 'failure_screen.dart' show failureReasonLabel;

/// 11 · Retour du colis : itinéraire jusqu'au vendeur, puis, sur place, les frais de retour
/// que son solde ne couvre pas (pas de paiement, pas de colis), le code de retour qu'il a
/// reçu par SMS et la photo du colis rendu. Le retour passe par la file hors connexion.
class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onReturned,
    this.now,
  });

  final RiderOrder order;
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis rendu : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onReturned;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  final _code = TextEditingController();
  bool _arrived = false;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  /// Frais de retour à encaisser auprès de l'expéditeur (E6) : null tant qu'ils ne sont pas
  /// connus, 0 s'il n'y a rien (ou plus rien) à payer.
  int? _fees;
  bool _feesOffline = false;
  bool _feesPaidHere = false;
  bool _momoOpen = false;
  bool _feesWaiting = false;
  String? _feesOperator;
  late final _feesPhone = TextEditingController(text: _senderLocalPhone());
  Timer? _feesPoll;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'return');
    if (refused != null) {
      _arrived = true;
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadFees());
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _feesPhone.dispose();
    _feesPoll?.cancel();
    super.dispose();
  }

  String _senderLocalPhone() {
    final phone = widget.order.sender.phone ?? widget.order.pickup.contactPhone ?? '';
    final local = digitsOf(phone).replaceFirst(RegExp(r'^237(?=\d{9}$)'), '');
    return PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: local)).text;
  }

  void _arrive() {
    setState(() => _arrived = true);
    unawaited(_loadFees());
  }

  Future<void> _loadFees() async {
    setState(() => _feesOffline = false);
    try {
      final collection = await ref.read(riderApiProvider).collection(widget.order.id);
      if (!mounted) return;
      setState(() {
        _fees = collection.complete ? 0 : collection.total;
        _feesWaiting = !collection.complete && collection.paymentStatus == 'PENDING';
      });
      if (_feesWaiting) _pollFees();
    } catch (_) {
      // Pas de réseau : le retour part dans la file, le serveur vérifiera.
      if (mounted) setState(() => _feesOffline = true);
    }
  }

  void _feesSettled(Collection collection) {
    setState(() {
      _fees = collection.complete ? 0 : collection.total;
      _feesPaidHere = collection.complete;
      _feesWaiting = !collection.complete && collection.paymentStatus == 'PENDING';
    });
    if (collection.complete) {
      _feesPoll?.cancel();
      TaraFeedback.play(context, TaraSound.cash);
    }
  }

  Future<void> _collectCash() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final collection = await ref.read(riderApiProvider).collectCash(widget.order.id);
      if (mounted) _feesSettled(collection);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMomo() async {
    final l = AppLocalizations.of(context);
    final operator = _feesOperator;
    final phone = digitsOf(_feesPhone.text);
    if (operator == null) return;
    if (!isCameroonMobile(phone)) {
      setState(() => _error = l.phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final collection = await ref
          .read(riderApiProvider)
          .collectMobileMoney(widget.order.id, phone: phone, operator: operator);
      if (!mounted) return;
      _feesSettled(collection);
      if (!collection.complete) {
        setState(() => _feesWaiting = true);
        _pollFees();
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pollFees() {
    _feesPoll?.cancel();
    _feesPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final collection = await ref.read(riderApiProvider).collection(widget.order.id);
        if (!mounted) return;
        if (collection.complete) {
          _feesSettled(collection);
        } else if (collection.paymentStatus != 'PENDING') {
          _feesPoll?.cancel();
          setState(() {
            _feesWaiting = false;
            _error = AppLocalizations.of(context).momoFailed;
          });
        }
      } catch (_) {
        // Réseau : nouvel essai au prochain tour.
      }
    });
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
    final result = await actions.returnToSender(
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
      return;
    }
    widget.onReturned(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final phone = order.sender.phone ?? order.pickup.contactPhone;
    final reason = order.failureReason;
    // Pas de paiement, pas de colis : les frais non couverts sont encaissés d'abord (sans
    // réseau, le retour part dans la file et le serveur vérifie).
    final feesOk = _fees == 0 || _feesOffline;
    final ready = _photoPath != null && _code.text.length == 4 && feesOk;
    final step = !_arrived ? 0 : (_code.text.length == 4 ? 2 : 1);

    return CourseScaffold(
      order: order,
      stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
      title: (route, _) => route?.minutes == null ? l.returnTitle : l.returnMinutes(route!.minutes!),
      onBack: widget.onBack,
      onSos: widget.onSos,
      footer: _arrived
          ? PrimaryButton(
              label: l.parcelReturned,
              icon: TaraIcons.check,
              loading: _busy,
              onPressed: ready ? _submit : null,
            )
          : PrimaryButton(label: l.atSender, icon: TaraIcons.mapPin, onPressed: _arrive),
      children: [
        if (reason != null) Align(alignment: Alignment.centerLeft, child: _FailureChip(failureReasonLabel(l, reason))),
        const SizedBox(height: 12),
        CourseFieldLabel(l.returnTo),
        const SizedBox(height: 8),
        PartyRow(
          name: senderName,
          line: order.pickup.line,
          callLabel: l.callPerson(senderName),
          onCall: phone == null ? null : () => callPhone(phone),
        ),
        const SizedBox(height: 14),
        _ReturnSteps(
          labels: [l.returnStepJoin, l.returnStepCode, l.returnStepPhoto],
          active: step,
          inProgress: l.stepInProgress,
        ),
        if (_arrived) ...[
          const SizedBox(height: 14),
          if (_feesOffline) ...[
            ErrorLine(l.returnFeesOffline),
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(label: l.retry, onPressed: () => unawaited(_loadFees())),
            ),
            const SizedBox(height: 8),
          ] else if (_fees == null) ...[
            Text(l.returnFeesChecking, style: TaraText.small.copyWith(color: TaraColors.of(context).textSecondary)),
            const SizedBox(height: 12),
          ] else if (_fees! > 0) ...[
            _ReturnFeesCard(
              name: senderName,
              amount: _fees!,
              busy: _busy,
              momoOpen: _momoOpen,
              waiting: _feesWaiting,
              operator: _feesOperator,
              operators: ref.watch(riderConfigProvider).value?.operators ?? const <MobileMoneyOperator>[],
              phone: _feesPhone,
              onCash: () => unawaited(_collectCash()),
              onOpenMomo: () => setState(() => _momoOpen = true),
              onOperator: (value) => setState(() => _feesOperator = value),
              onSend: () => unawaited(_sendMomo()),
            ),
            const SizedBox(height: 14),
          ] else if (_feesPaidHere) ...[
            _FeesPaid(text: l.returnFeesPaid),
            const SizedBox(height: 14),
          ],
          CourseFieldLabel(l.returnCodeLabel, hint: l.returnCodeHint),
          const SizedBox(height: 8),
          CodeCells(length: 4, controller: _code, cellHeight: 56, autofocus: false, digitLabel: l.digitLabel),
          const SizedBox(height: 12),
          ProofPhotoTile(
            path: _photoPath,
            takenAt: _photoAt,
            onTake: _busy ? null : _takePhoto,
            title: l.photoReturned,
            hint: l.photoReturnedHint,
            takenLabel: l.photoReturnedTaken,
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Pastille « Échec · Client absent ».
class _FailureChip extends StatelessWidget {
  const _FailureChip(this.reason);
  final String reason;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dangerText.withValues(alpha: .35)),
      ),
      child: Text(
        AppLocalizations.of(context).failureChip(reason),
        style: TaraText.smallStrong.copyWith(color: c.dangerTextStrong),
      ),
    );
  }
}

/// Étapes du retour : rejoindre le vendeur, code de retour, photo du colis rendu.
class _ReturnSteps extends StatelessWidget {
  const _ReturnSteps({required this.labels, required this.active, required this.inProgress});
  final List<String> labels;
  final int active;
  final String inProgress;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == labels.length - 1 ? 0 : 10),
            child: MergeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == active ? TaraBrand.gradient : null,
                      color: i < active ? c.successTintBg : (i > active ? c.chipBg : null),
                      border: i > active ? Border.all(color: c.chipBorder) : null,
                    ),
                    child: i < active
                        ? TaraIcon(TaraIcons.check, size: 16, color: c.success)
                        : Text(
                            '${i + 1}',
                            style: TaraText.smallStrong.copyWith(
                              color: i == active ? TaraBrand.onBrand : c.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labels[i],
                      style: TaraText.text.copyWith(
                        color: i <= active ? c.textPrimary : c.textSecondary,
                        fontWeight: i == active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (i == active) Text(inProgress, style: TaraText.smallStrong.copyWith(color: c.accentText)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// « Frais de retour à encaisser » : espèces (prises sur le solde du livreur, qui les garde)
/// ou demande Mobile Money au téléphone de l'expéditeur.
class _ReturnFeesCard extends StatelessWidget {
  const _ReturnFeesCard({
    required this.name,
    required this.amount,
    required this.busy,
    required this.momoOpen,
    required this.waiting,
    required this.operator,
    required this.operators,
    required this.phone,
    required this.onCash,
    required this.onOpenMomo,
    required this.onOperator,
    required this.onSend,
  });

  final String name;
  final int amount;
  final bool busy;
  final bool momoOpen;
  final bool waiting;
  final String? operator;
  final List<MobileMoneyOperator> operators;
  final TextEditingController phone;
  final VoidCallback onCash;
  final VoidCallback onOpenMomo;
  final ValueChanged<String> onOperator;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final money = '${formatAmount(amount)} F';
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.returnFeesTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(l.returnFeesBody(name, money), style: TaraText.text.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          GlassButton(label: l.returnFeesCash(money), icon: TaraIcons.cash, onPressed: busy || waiting ? null : onCash),
          const SizedBox(height: 6),
          Text(l.returnFeesCashNote, style: TaraText.small.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          if (!momoOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(label: l.returnFeesMomo, onPressed: busy ? null : onOpenMomo),
            )
          else ...[
            const SizedBox(height: 4),
            ChoiceChips<String>(
              options: [for (final o in operators) ChoiceOption(o.code, o.name)],
              selected: operator,
              onSelected: (value) {
                if (!waiting) onOperator(value);
              },
            ),
            const SizedBox(height: 10),
            TaraTextField(
              label: l.phoneLabel,
              hint: l.phoneHint,
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
            ),
            const SizedBox(height: 10),
            if (waiting)
              Text(
                l.returnFeesWaiting,
                style: TaraText.text.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
              )
            else
              GlassButton(
                label: l.returnFeesSend,
                icon: TaraIcons.phone,
                onPressed: busy || operator == null ? null : onSend,
              ),
          ],
        ],
      ),
    );
  }
}

/// Frais de retour réglés sur place.
class _FeesPaid extends StatelessWidget {
  const _FeesPaid({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.successTintBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.successTintBorder),
      ),
      child: Row(
        children: [
          TaraIcon(TaraIcons.check, size: 20, color: c.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
