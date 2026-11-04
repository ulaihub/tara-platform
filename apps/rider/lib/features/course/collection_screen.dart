import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'course_scaffold.dart';

/// Montants proposés (maquette 12) : le montant exact, puis les trois multiples de 5 000 FCFA
/// au-dessus (12 500 → 15 000, 20 000, 25 000).
List<int> receivedAmounts(int due) {
  const step = 5000;
  final first = (due ~/ step + 1) * step;
  return [due, for (var i = 0; i < 3; i++) first + i * step];
}

enum _Method { cash, mobileMoney }

enum _MomoState { idle, sending, waiting, failed, noAnswer }

/// 12 · Encaissement : espèces (montant reçu, monnaie à rendre) ou Mobile Money (demande au
/// téléphone du client, confirmation automatique). La livraison préparée à l'écran 09 part
/// juste après : encaisser puis livrer.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({
    super.key,
    required this.order,
    required this.draft,
    required this.onBack,
    required this.onDone,
    this.momoNoAnswerAfter = const Duration(minutes: 3),
  });

  final RiderOrder order;
  final DeliveryDraft draft;
  final VoidCallback onBack;

  /// Encaissé puis livré (envoyé ou gardé sur le téléphone).
  final void Function(ActionOutcome outcome) onDone;

  /// Sans réponse du client passé ce délai : proposer de renvoyer la demande.
  final Duration momoNoAnswerAfter;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  late final _phone = TextEditingController(text: _initialPhone());
  _Method _method = _Method.cash;
  late int _received = widget.order.collectAtDelivery;
  String? _operator;
  _MomoState _momo = _MomoState.idle;
  String? _paymentId;
  bool _busy = false;
  String? _error;
  StreamSubscription<RealtimeEvent>? _events;

  /// Abonnement temps réel à la course (événements `payment.status`), retiré à la sortie.
  RealtimeClient? _subscribed;
  Timer? _poll;
  Timer? _noAnswer;

  int get _due => widget.order.collectAtDelivery;

  String _initialPhone() {
    final digits = digitsOf(widget.order.recipient.phone ?? '').replaceFirst(RegExp('^237'), '');
    return PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
  }

  @override
  void initState() {
    super.initState();
    _operator = guessOperator(digitsOf(_phone.text));
    _phone.addListener(() {
      final guess = guessOperator(digitsOf(_phone.text));
      setState(() {
        _error = null;
        if (guess != null && _momo == _MomoState.idle) _operator = guess;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _poll?.cancel();
    _noAnswer?.cancel();
    _subscribed?.unsubscribeOrder(widget.order.id);
    _phone.dispose();
    super.dispose();
  }

  // --- Espèces ---------------------------------------------------------------------------------

  Future<void> _confirmCash() async {
    final l = AppLocalizations.of(context);
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
    final result = await actions.collectCashAndDeliver(widget.order, widget.draft, at: at);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _error = result.message ?? l.genericError;
      });
      return;
    }
    widget.onDone(result.outcome);
  }

  // --- Mobile Money ----------------------------------------------------------------------------

  Future<void> _sendRequest() async {
    final l = AppLocalizations.of(context);
    final digits = digitsOf(_phone.text);
    final operator = _operator;
    if (!isCameroonMobile(digits) || operator == null) {
      setState(() => _error = l.phoneInvalid);
      return;
    }
    setState(() {
      _momo = _MomoState.sending;
      _error = null;
    });
    final realtime = ref.read(realtimeProvider)..subscribeOrder(widget.order.id);
    _subscribed = realtime;
    unawaited(_events?.cancel());
    _events = realtime.stream.listen(_onEvent);
    try {
      final collection = await ref
          .read(riderApiProvider)
          .collectMobileMoney(widget.order.id, phone: '+237$digits', operator: operator);
      if (!mounted) return;
      if (collection.complete) {
        await _paid();
        return;
      }
      setState(() {
        _paymentId = collection.paymentId;
        _momo = _MomoState.waiting;
      });
      // Repli si le temps réel est coupé : on redemande l'état toutes les 5 s.
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_check()));
      _noAnswer?.cancel();
      _noAnswer = Timer(widget.momoNoAnswerAfter, () {
        if (mounted && _momo == _MomoState.waiting) setState(() => _momo = _MomoState.noAnswer);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _momo = _MomoState.idle;
        _error = error.isNetwork ? l.momoNeedsNetwork : errorMessage(context, error);
      });
    }
  }

  void _onEvent(RealtimeEvent event) {
    if (event.name != 'payment.status' || event.payload['orderId'] != widget.order.id) return;
    // Un ancien paiement de la course (demande précédente) ne compte pas.
    final paymentId = _paymentId;
    if (paymentId != null && event.payload['paymentId'] != paymentId) return;
    switch (event.payload['status']) {
      case 'SUCCEEDED':
        unawaited(_paid());
      case 'FAILED' || 'CANCELLED':
        _failed();
    }
  }

  Future<void> _check() async {
    if (_momo != _MomoState.waiting && _momo != _MomoState.noAnswer) return;
    try {
      final collection = await ref.read(riderApiProvider).collection(widget.order.id);
      if (!mounted) return;
      if (collection.complete) {
        await _paid();
      } else if (collection.paymentId == null) {
        _failed();
      }
    } catch (_) {
      // Réseau coupé : on réessaiera au prochain passage.
    }
  }

  void _failed() {
    _poll?.cancel();
    _noAnswer?.cancel();
    if (mounted) setState(() => _momo = _MomoState.failed);
  }

  /// Paiement confirmé : la livraison préparée part aussitôt.
  Future<void> _paid() async {
    if (_busy) return;
    _poll?.cancel();
    _noAnswer?.cancel();
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
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
    final result = await actions.deliverDraft(widget.order, widget.draft, at: at);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _error = result.message ?? l.genericError;
      });
      return;
    }
    widget.onDone(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final name = order.recipient.name ?? order.dropoff.contactName ?? order.reference;
    final cash = _method == _Method.cash;
    final operators = ref.watch(riderConfigProvider).value?.operators ?? const <MobileMoneyOperator>[];
    final waiting = _momo == _MomoState.sending || _momo == _MomoState.waiting || _momo == _MomoState.noAnswer;
    final change = _received - _due;

    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(
                icon: TaraIcons.chevronLeft,
                label: l.back,
                onPressed: _busy || waiting ? null : widget.onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.collectionSubtitle(order.reference, name),
                      style: TaraText.small.copyWith(color: c.textSecondary),
                    ),
                    Semantics(
                      header: true,
                      child: Text(l.collectionTitle, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AmountCard(amount: _due, label: l.toCollectFromCustomer),
          const SizedBox(height: 16),
          LiquidSegmented<_Method>(
            segments: [(_Method.cash, l.methodCash), (_Method.mobileMoney, l.methodMomo)],
            selected: _method,
            onChanged: (value) {
              if (_busy || waiting) return;
              setState(() {
                _method = value;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 18),
          if (cash) ...[
            CourseFieldLabel(l.amountReceived),
            const SizedBox(height: 8),
            ChoiceChips<int>(
              options: [
                for (final amount in receivedAmounts(_due))
                  ChoiceOption(
                    amount,
                    amount == _due ? l.exactAmount('${formatAmount(amount)} F') : '${formatAmount(amount)} F',
                  ),
              ],
              selected: _received,
              onSelected: (value) => setState(() => _received = value),
              height: 50,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(l.changeToGive, style: TaraText.text.copyWith(color: c.textSecondary)),
                ),
                Text(
                  '${formatAmount(change < 0 ? 0 : change)} F',
                  style: TaraText.titlePanel.copyWith(color: c.success, fontFeatures: TaraText.tabular),
                ),
              ],
            ),
          ] else ...[
            CourseFieldLabel(l.customerOperator),
            const SizedBox(height: 8),
            ChoiceChips<String>(
              options: [for (final operator in operators) ChoiceOption(operator.code, operator.name)],
              selected: _operator,
              onSelected: (value) {
                if (!waiting) setState(() => _operator = value);
              },
              height: 50,
            ),
            const SizedBox(height: 14),
            TaraTextField(
              label: l.customerMomoNumber,
              hint: l.phoneHint,
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
            ),
            const SizedBox(height: 12),
            _MomoNote(
              text: switch (_momo) {
                _MomoState.waiting || _MomoState.sending => l.momoWaiting,
                _MomoState.noAnswer => l.momoNoAnswer,
                _ => l.momoHint,
              },
              active: waiting,
            ),
            if (_momo == _MomoState.failed) ...[const SizedBox(height: 12), CourseWarning(l.momoFailed)],
          ],
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            if (cash) ...[
              // Solde prépayé (G5) : l'argent encaissé en espèces est pris sur le solde, où
              // il est mis de côté depuis l'acceptation. Libellé à gauche, montant à droite.
              MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(l.takenFromBalance, style: TaraText.label.copyWith(color: c.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${formatAmount(-_due)} F',
                      style: TaraText.label.copyWith(
                        color: c.accentStrongText,
                        fontWeight: FontWeight.w800,
                        fontFeatures: TaraText.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (cash)
              PrimaryButton(
                label: l.confirmCollection,
                icon: TaraIcons.check,
                loading: _busy,
                onPressed: _change >= 0 ? _confirmCash : null,
              )
            else
              PrimaryButton(
                label: switch (_momo) {
                  _MomoState.failed || _MomoState.noAnswer => l.resendPaymentRequest,
                  // Attente : l'état reste lisible même quand la note est hors de l'écran.
                  _MomoState.waiting => l.paymentRequestSent,
                  _ => l.sendPaymentRequest,
                },
                icon: TaraIcons.arrowRight,
                loading: _busy || _momo == _MomoState.sending || _momo == _MomoState.waiting,
                onPressed: _operator == null ? null : _sendRequest,
              ),
          ],
        ),
      ),
    );
  }

  int get _change => _received - _due;
}

/// Montant à encaisser, sur une carte en verre que remplit une vague (A2).
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount, required this.label});
  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 136,
        child: Stack(
          children: [
            const Positioned.fill(
              child: GlassCard(radius: 28, shadow: false, padding: EdgeInsets.zero, child: SizedBox.expand()),
            ),
            Positioned.fill(
              child: LiquidFill(
                level: .32,
                front: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [TaraBrand.amber.withValues(alpha: .75), TaraBrand.orange.withValues(alpha: .55)],
                ),
                back: TaraBrand.red.withValues(alpha: .35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TaraText.label.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AmountText(
                      amount,
                      style: TaraText.amountXL,
                      unitStyle: TaraText.unit.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explication de la demande Mobile Money ; gouttes qui fusionnent pendant l'attente.
class _MomoNote extends StatelessWidget {
  const _MomoNote({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 18,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: active ? const GooLoader(compact: true) : TaraIcon(TaraIcons.phone, size: 20, color: c.accentText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
