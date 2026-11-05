import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// Adresses demandées par lien (B3), les plus récentes d'abord.
final locationLinksProvider = FutureProvider<List<LocationLink>>((ref) => ref.read(clientApiProvider).locationLinks());

/// « Demander l'adresse » depuis l'accueil (B3) : le lien part par WhatsApp ou SMS ; le
/// destinataire place son point sur la page web ; l'expéditeur est prévenu et crée la
/// livraison avec cette adresse, sans rien ressaisir.
class AskAddressScreen extends ConsumerStatefulWidget {
  const AskAddressScreen({super.key, required this.me, required this.onBack, required this.onCreateOrder});

  final Me me;
  final VoidCallback onBack;

  /// Livraison à créer avec le destinataire et l'adresse (ou le lien en attente).
  final ValueChanged<LocationLink> onCreateOrder;

  @override
  ConsumerState<AskAddressScreen> createState() => _AskAddressScreenState();
}

class _AskAddressScreenState extends ConsumerState<AskAddressScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 280, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.8), size: 230, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 5)),
  ];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _notice;
  StreamSubscription<RealtimeEvent>? _events;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _error = null));
    _phone.addListener(() => setState(() => _error = null));
    // Point placé par un destinataire : la liste est relue, le son l'annonce.
    _events = ref.read(realtimeProvider).stream.listen((event) {
      if (event.name != 'location-link.submitted' || !mounted) return;
      TaraFeedback.play(context, TaraSound.received);
      ref.invalidate(locationLinksProvider);
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _senderName => widget.me.merchant?.shopName ?? widget.me.fullName ?? '';

  static String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

  /// Message prêt dans WhatsApp ou les SMS du téléphone, au numéro du destinataire.
  Future<bool> _open(LocationLink link, String name, String phone, {required bool whatsapp}) {
    final l = AppLocalizations.of(context);
    final text = l.locationLinkMessage(_firstName(name), _senderName, link.url);
    final uri = whatsapp
        ? Uri.parse('https://wa.me/237$phone?text=${Uri.encodeComponent(text)}')
        : Uri.parse('sms:+237$phone?body=${Uri.encodeComponent(text)}');
    return ref.read(launcherProvider)(uri);
  }

  Future<void> _send({required bool whatsapp}) async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final phone = digitsOf(_phone.text);
    if (name.length < 2 || !isCameroonMobile(phone)) {
      setState(() => _error = l.recipientFirst);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    try {
      final link = await ref
          .read(clientApiProvider)
          .createLocationLink(recipientName: name, recipientPhone: '+237$phone');
      if (!mounted) return;
      final opened = await _open(link, name, phone, whatsapp: whatsapp);
      if (!mounted) return;
      ref.invalidate(locationLinksProvider);
      setState(() {
        if (!opened) _error = whatsapp ? l.whatsappUnavailable : l.smsUnavailable;
        _notice = l.askSent(_firstName(name));
        _name.clear();
        _phone.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Lien expiré : un nouveau lien au même destinataire, renvoyé par WhatsApp.
  Future<void> _resend(LocationLink old) async {
    final phone = digitsOf(old.recipientPhone ?? '').replaceFirst(RegExp('^237'), '');
    final name = old.recipientName ?? '';
    try {
      final link = await ref
          .read(clientApiProvider)
          .createLocationLink(recipientName: name, recipientPhone: '+237$phone');
      await _open(link, name, phone, whatsapp: true);
      ref.invalidate(locationLinksProvider);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final links = ref.watch(locationLinksProvider);
    return TaraScreen(
      blobs: _blobs,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(locationLinksProvider);
          await ref.read(locationLinksProvider.future).catchError((_) => <LocationLink>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(l.askTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(height: 8),
            Text(l.askIntro, style: TaraText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: 18),
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaraTextField(
                    label: l.recipientName,
                    hint: l.recipientNameHint,
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 12),
                  TaraTextField(
                    label: l.recipientPhone,
                    hint: l.phoneHint,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                    leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
                  ),
                  if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: l.askSendWhatsapp,
                    icon: TaraIcons.send,
                    loading: _sending,
                    onPressed: () => unawaited(_send(whatsapp: true)),
                  ),
                  Center(
                    child: TaraLink(
                      label: l.askSendSms,
                      onPressed: _sending ? null : () => unawaited(_send(whatsapp: false)),
                    ),
                  ),
                ],
              ),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              TintBox(
                tone: TintTone.success,
                child: Semantics(
                  liveRegion: true,
                  child: Text(_notice!, style: TaraText.label.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SectionHeader(title: l.askRequested),
            const SizedBox(height: 8),
            switch (links) {
              AsyncData(:final value) when value.isEmpty => GlassCard(
                radius: 20,
                shadow: false,
                padding: const EdgeInsets.all(16),
                child: Text(l.askNone, style: TaraText.label.copyWith(color: c.textSecondary)),
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final link in value.take(20)) ...[
                    _LinkRow(
                      link: link,
                      onCreate: () => widget.onCreateOrder(link),
                      onResend: () => unawaited(_resend(link)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
              AsyncError() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ErrorLine(l.genericError),
                  const SizedBox(height: 8),
                  GlassButton(label: l.retry, height: 44, onPressed: () => ref.invalidate(locationLinksProvider)),
                ],
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: GooLoader(compact: true)),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Une adresse demandée : en attente, reçue (repère affiché) ou expirée.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onCreate, required this.onResend});

  final LocationLink link;
  final VoidCallback onCreate;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final until = DateFormat(locale == 'fr' ? "d MMM 'à' HH'h'mm" : "d MMM 'at' HH:mm", locale);
    final (icon, tone, status) = switch (link.status) {
      'SUBMITTED' => (TaraIcons.mapPin, TintTone.success, l.askReceived(link.address?.landmark ?? '')),
      'EXPIRED' => (TaraIcons.clock, TintTone.danger, l.askExpired),
      _ => (TaraIcons.send, TintTone.accent, l.askPending(until.format(link.expiresAt.toLocal()))),
    };
    final phone = link.recipientPhone == null ? '' : displayPhone(link.recipientPhone!);
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: icon, size: 40, radius: 13, tone: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [link.recipientName ?? '', phone].where((part) => part.isNotEmpty).join(' · '),
                        style: TaraText.text.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TaraText.small.copyWith(
                          color: link.status == 'SUBMITTED' ? c.success : c.textSecondary,
                          fontWeight: link.status == 'SUBMITTED' ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (link.status == 'SUBMITTED') ...[
            const SizedBox(height: 10),
            PrimaryButton(label: l.askCreateOrder, icon: TaraIcons.arrowRight, onPressed: onCreate),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TaraLink(
                label: link.status == 'EXPIRED' ? l.askResend : l.askCreateOrder,
                onPressed: link.status == 'EXPIRED' ? onResend : onCreate,
              ),
            ),
        ],
      ),
    );
  }
}
