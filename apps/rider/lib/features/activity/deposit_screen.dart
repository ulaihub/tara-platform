import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/offline/action_queue.dart' show newEventId;
import '../../core/realtime/realtime_client.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/inputs.dart';
import '../../design/components/layout.dart';
import '../../design/format.dart';
import '../../design/motion/effects.dart';
import '../../design/motion/liquid_background.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/phone_format.dart';
import '../course/collection_screen.dart' show guessOperator;
import '../course/course_scaffold.dart' show CourseFieldLabel;

enum _DepositState { idle, sending, waiting, done, failed }

/// Dépôt des espèces détenues (G5) par Mobile Money : une demande de paiement part sur le
/// téléphone du livreur, confirmée en direct (sinon relue toutes les 5 s).
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key, required this.amount, required this.onBack, required this.onDone});

  /// Espèces détenues, déposées en une fois.
  final int amount;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  final _phone = TextEditingController();
  String? _operator;
  _DepositState _state = _DepositState.idle;
  String? _error;
  String? _paymentId;

  /// Même demande renvoyée (réponse perdue) : pas de second paiement.
  String _key = newEventId();
  StreamSubscription<RealtimeEvent>? _events;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      final guess = guessOperator(digitsOf(_phone.text));
      setState(() {
        _error = null;
        if (guess != null && _state == _DepositState.idle) _operator = guess;
      });
    });
    unawaited(_prefillPhone());
  }

  /// Numéro du livreur proposé par défaut (modifiable).
  Future<void> _prefillPhone() async {
    try {
      final me = await ref.read(riderApiProvider).me();
      final digits = digitsOf(me['phone'] as String? ?? '').replaceFirst(RegExp('^237'), '');
      if (!mounted || _phone.text.isNotEmpty) return;
      _phone.text = PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
    } catch (_) {
      // Sans réseau : le livreur tape son numéro.
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _poll?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final digits = digitsOf(_phone.text);
    final operator = _operator;
    if (!isCameroonMobile(digits) || operator == null) {
      setState(() => _error = l.phoneInvalid);
      return;
    }
    setState(() {
      _state = _DepositState.sending;
      _error = null;
    });
    unawaited(_events?.cancel());
    _events = ref.read(realtimeProvider).stream.listen(_onEvent);
    try {
      final payment = await ref
          .read(riderApiProvider)
          .depositCash(amount: widget.amount, phone: '+237$digits', operator: operator, idempotencyKey: _key);
      if (!mounted) return;
      _paymentId = payment.id;
      _apply(payment.status);
      if (_state == _DepositState.sending) setState(() => _state = _DepositState.waiting);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_check()));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _DepositState.idle;
        _error = error.isNetwork ? l.momoNeedsNetwork : errorMessage(context, error);
      });
    }
  }

  void _onEvent(RealtimeEvent event) {
    if (event.name != 'payment.status' || event.payload['paymentId'] != _paymentId) return;
    _apply(event.payload['status'] as String?);
  }

  Future<void> _check() async {
    final id = _paymentId;
    if (id == null || _state != _DepositState.waiting) return;
    try {
      _apply((await ref.read(riderApiProvider).payment(id)).status);
    } catch (_) {
      // Réseau coupé : prochain passage.
    }
  }

  void _apply(String? status) {
    if (!mounted) return;
    switch (status) {
      case 'SUCCEEDED':
        _poll?.cancel();
        setState(() => _state = _DepositState.done);
      case 'FAILED' || 'CANCELLED':
        _poll?.cancel();
        setState(() {
          _state = _DepositState.failed;
          // Nouvelle demande : nouvel identifiant.
          _key = newEventId();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final operators = ref.watch(riderConfigProvider).value?.operators ?? const <MobileMoneyOperator>[];
    final amount = '${formatAmount(widget.amount)} F';
    final busy = _state == _DepositState.sending || _state == _DepositState.waiting;
    final done = _state == _DepositState.done;

    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: busy ? null : widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.depositTitle, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.cashToDeposit, style: TaraText.label.copyWith(color: c.textSecondary)),
                const SizedBox(height: 4),
                AmountText(widget.amount, style: TaraText.amountL),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (done)
            TintBox(
              tone: TintTone.success,
              child: Semantics(
                liveRegion: true,
                child: Text(l.depositDone(amount), style: TaraText.text.copyWith(color: c.textPrimary)),
              ),
            )
          else ...[
            CourseFieldLabel(l.depositOperator),
            const SizedBox(height: 8),
            ChoiceChips<String>(
              options: [for (final operator in operators) ChoiceOption(operator.code, operator.name)],
              selected: _operator,
              onSelected: (value) {
                if (!busy) setState(() => _operator = value);
              },
            ),
            const SizedBox(height: 14),
            TaraTextField(
              label: l.depositNumber,
              hint: l.phoneHint,
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
            ),
            const SizedBox(height: 12),
            TintBox(
              child: Row(
                children: [
                  if (busy) ...[const SizedBox(width: 44, child: GooLoader(compact: true)), const SizedBox(width: 10)],
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        busy ? l.depositWaiting : l.depositBody(amount),
                        style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(l.depositOffice, style: TaraText.small.copyWith(color: c.textTertiary)),
            if (_state == _DepositState.failed) ...[const SizedBox(height: 12), ErrorLine(l.depositFailed)],
          ],
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: done
            ? PrimaryButton(label: l.close, icon: TaraIcons.check, onPressed: widget.onDone)
            : PrimaryButton(
                label: l.depositSend,
                icon: TaraIcons.arrowRight,
                loading: busy,
                onPressed: _operator == null || widget.amount <= 0 ? null : _send,
              ),
      ),
    );
  }
}
