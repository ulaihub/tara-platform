import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';
import 'pickup_step.dart';

/// Destinataires déjà servis, avec leur dernière adresse (B4, B5).
final recipientsProvider = FutureProvider.autoDispose<List<Recipient>>(
  (ref) => ref.read(clientApiProvider).recipients(),
);

/// Étape 2 · Destinataire : nom, numéro (ou un récent du carnet), puis l'adresse, placée
/// sur la carte ou demandée au destinataire par un lien de localisation (B3).
class RecipientStep extends ConsumerStatefulWidget {
  const RecipientStep({
    super.key,
    required this.draft,
    required this.senderName,
    required this.showErrors,
    required this.onPlaceOnMap,
  });

  final OrderDraft draft;

  /// Nom de l'expéditeur (ou de sa boutique), cité dans le message du lien.
  final String senderName;

  /// « Continuer » a été touché alors que l'étape est incomplète.
  final bool showErrors;
  final VoidCallback onPlaceOnMap;

  @override
  ConsumerState<RecipientStep> createState() => _RecipientStepState();
}

class _RecipientStepState extends ConsumerState<RecipientStep> {
  late final _name = TextEditingController(text: _delivery.recipientName);
  late final _phone = TextEditingController(text: _grouped(_delivery.recipientPhone));
  bool _sending = false;
  String? _error;

  DeliveryDraft get _delivery => widget.draft.delivery;

  static String _grouped(String digits) =>
      PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_name.text == _delivery.recipientName) return;
      _error = null;
      widget.draft.update((d) => d.recipientName = _name.text);
    });
    _phone.addListener(() {
      final digits = digitsOf(_phone.text);
      if (digits == _delivery.recipientPhone) return;
      _error = null;
      widget.draft.update((d) => d.recipientPhone = digits);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Un récent du carnet : nom, numéro et sa dernière adresse d'un coup.
  void _pick(Recipient recipient) {
    final digits = digitsOf(recipient.phone).replaceFirst(RegExp(r'^237(?=\d{9}$)'), '');
    widget.draft.update(
      (d) => d
        ..recipientName = recipient.name
        ..recipientPhone = digits
        ..dropoff = recipient.lastAddress
        ..link = null,
    );
    _name.text = recipient.name;
    _phone.text = _grouped(digits);
    FocusScope.of(context).unfocus();
  }

  /// Crée le lien (une fois) puis ouvre WhatsApp ou les SMS avec le message prêt.
  Future<void> _ask({required bool whatsapp}) async {
    final l = AppLocalizations.of(context);
    if (!_delivery.hasRecipient) {
      setState(() => _error = l.recipientFirst);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final current = _delivery.link;
      final link = current != null && current.status == 'PENDING'
          ? current
          : await ref
                .read(clientApiProvider)
                .createLocationLink(
                  recipientName: _delivery.recipientName.trim(),
                  recipientPhone: '+237${_delivery.recipientPhone}',
                );
      if (!mounted) return;
      widget.draft.update((d) => d.link = link);
      final text = l.locationLinkMessage(_firstName(_delivery.recipientName), widget.senderName, link.url);
      final phone = _delivery.recipientPhone;
      final uri = whatsapp
          ? Uri.parse('https://wa.me/237$phone?text=${Uri.encodeComponent(text)}')
          : Uri.parse('sms:+237$phone?body=${Uri.encodeComponent(text)}');
      final opened = await ref.read(launcherProvider)(uri);
      if (!opened && mounted) setState(() => _error = whatsapp ? l.whatsappUnavailable : l.smsUnavailable);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final d = _delivery;
    final showErrors = widget.showErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.recipientTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 8),
        Text(l.recipientBody, style: TaraText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 18),
        _Recents(draft: widget.draft, onPick: _pick),
        TaraTextField(
          label: l.recipientName,
          hint: l.recipientNameHint,
          controller: _name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
        ),
        if (showErrors && d.recipientName.trim().length < 2) ...[
          const SizedBox(height: 6),
          ErrorLine(l.recipientNameRequired),
        ],
        const SizedBox(height: 12),
        TaraTextField(
          label: l.recipientPhone,
          hint: l.phoneHint,
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [PhoneInputFormatter()],
          leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
        ),
        if (showErrors && !isCameroonMobile(d.recipientPhone)) ...[
          const SizedBox(height: 6),
          ErrorLine(l.phoneInvalid),
        ],
        const SizedBox(height: 22),
        Text(l.deliveryAddress, style: TaraText.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        if (d.dropoff case final address?) ...[
          AddressChoice(
            icon: TaraIcons.mapPin,
            title: address.neighborhood?.name ?? l.deliveryAddress,
            subtitle: address.landmark,
            selected: true,
            badge: address.verified
                ? l.addressVerified
                : d.link?.address?.id == address.id
                ? l.addressFromRecipient
                : null,
            onTap: widget.onPlaceOnMap,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TaraLink(
              label: l.changeAddress,
              onPressed: () => widget.draft.update(
                (d) => d
                  ..dropoff = null
                  ..link = null,
              ),
            ),
          ),
        ] else if (d.link case final link?)
          _LinkCard(
            link: link,
            name: _firstName(d.recipientName),
            sending: _sending,
            onWhatsapp: () => unawaited(_ask(whatsapp: true)),
            onSms: () => unawaited(_ask(whatsapp: false)),
            onPlaceMyself: widget.onPlaceOnMap,
          )
        else ...[
          _Option(icon: TaraIcons.mapPin, title: l.placeOnMap, body: l.placeOnMapBody, onTap: widget.onPlaceOnMap),
          const SizedBox(height: 10),
          _Option(
            icon: TaraIcons.send,
            title: l.askRecipient,
            body: l.askRecipientBody,
            actions: Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: l.viaWhatsapp,
                    icon: TaraIcons.message,
                    color: c.accentText,
                    onPressed: _sending ? null : () => unawaited(_ask(whatsapp: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: l.viaSms,
                    icon: TaraIcons.message,
                    onPressed: _sending ? null : () => unawaited(_ask(whatsapp: false)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
        if (showErrors && !d.hasAddress && _error == null) ...[
          const SizedBox(height: 10),
          ErrorLine(l.addressRequired),
        ],
      ],
    );
  }
}

/// Récents du carnet, en bulles qui défilent : un toucher remplit nom, numéro et adresse.
/// La saisie filtre la liste.
class _Recents extends ConsumerWidget {
  const _Recents({required this.draft, required this.onPick});

  final OrderDraft draft;
  final ValueChanged<Recipient> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final all = ref.watch(recipientsProvider).value ?? const <Recipient>[];
    final d = draft.delivery;
    final name = d.recipientName.trim().toLowerCase();
    final phone = d.recipientPhone;
    final shown = [
      for (final r in all)
        if ((name.isEmpty || r.name.toLowerCase().contains(name)) &&
            (phone.isEmpty || digitsOf(r.phone).contains(phone)))
          r,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.recentRecipients, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in shown)
                  _RecentBubble(
                    recipient: r,
                    selected: r.name == d.recipientName && digitsOf(r.phone).endsWith(phone) && phone.length == 9,
                    onTap: () => onPick(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBubble extends StatelessWidget {
  const _RecentBubble({required this.recipient, required this.selected, required this.onTap});

  final Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final r = recipient;
    return Semantics(
      button: true,
      selected: selected,
      label: [
        r.name,
        displayPhone(r.phone),
        r.lastAddress.summary,
        if (r.lastAddress.verified) l.addressVerified,
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? c.accentText : const Color(0x00000000), width: 2),
                    ),
                    child: InitialsAvatar(name: r.name, size: 50),
                  ),
                  if (r.lastAddress.verified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: c.glassStrong, shape: BoxShape.circle),
                        child: TaraIcon(TaraIcons.shieldCheck, size: 16, color: c.success),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.name.trim().split(RegExp(r'\s+')).first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TaraText.smallStrong.copyWith(color: selected ? c.accentText : c.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Façon de donner l'adresse : icône, titre, explication, actions éventuelles.
class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.body, this.onTap, this.actions});

  final TaraIconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 20,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(icon: icon, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(body, style: TaraText.small.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
                  ],
                ],
              ),
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien envoyé : attente du point placé par le destinataire, ou lien expiré.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.name,
    required this.sending,
    required this.onWhatsapp,
    required this.onSms,
    required this.onPlaceMyself,
  });

  final LocationLink link;
  final String name;
  final bool sending;
  final VoidCallback onWhatsapp;
  final VoidCallback onSms;
  final VoidCallback onPlaceMyself;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final expired = link.status == 'EXPIRED';
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: TaraIcons.send, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.linkSentTitle(name),
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expired ? l.linkExpired : l.linkWaiting,
                      style: TaraText.small.copyWith(color: expired ? c.dangerText : c.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (!expired) ...[const SizedBox(width: 8), const GooLoader(compact: true)],
            ],
          ),
          const SizedBox(height: 12),
          Text(l.resendLink, style: TaraText.small.copyWith(color: c.textTertiary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: l.viaWhatsapp,
                  icon: TaraIcons.refresh,
                  height: 44,
                  color: c.accentText,
                  onPressed: sending ? null : onWhatsapp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: l.viaSms,
                  icon: TaraIcons.refresh,
                  height: 44,
                  onPressed: sending ? null : onSms,
                ),
              ),
            ],
          ),
          Center(
            child: TaraLink(label: l.placeMyself, onPressed: onPlaceMyself),
          ),
        ],
      ),
    );
  }
}
