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
import '../bulk/bulk_draft.dart';
import '../bulk/contacts_screen.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
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

  /// Destinataire déjà servi qui a ce numéro : sa dernière adresse est proposée.
  Recipient? _known(List<Recipient> all) {
    final phone = _delivery.recipientPhone;
    if (phone.length != 9) return null;
    for (final r in all) {
      if (digitsOf(r.phone).endsWith(phone)) return r;
    }
    return null;
  }

  /// Contacts du téléphone et destinataires récents : un choix remplit nom, numéro (et la
  /// dernière adresse d'un récent).
  Future<void> _pickContact() async {
    FocusScope.of(context).unfocus();
    final picked = await Navigator.of(context)
        .push<List<BulkLine>>(scopedPage(context, (_) => const ContactsScreen(room: 1, already: {})));
    final line = picked?.firstOrNull;
    if (line == null || !mounted) return;
    widget.draft.update(
      (d) => d
        ..recipientName = line.name
        ..recipientPhone = line.phone
        ..dropoff = line.dropoff ?? d.dropoff
        ..link = line.dropoff == null ? d.link : null,
    );
    _name.text = line.name;
    _phone.text = _grouped(line.phone);
  }

  /// « Où livrer ? » choisi d'après l'état : lien envoyé, adresse connue, point placé.
  _Where? _where(Recipient? known) {
    final d = _delivery;
    if (d.link != null && d.dropoff == null) return _Where.ask;
    if (d.dropoff case final address?) {
      if (d.link?.address?.id == address.id) return _Where.ask;
      return known != null && known.lastAddress.id == address.id ? _Where.known : _Where.map;
    }
    return _mode;
  }

  _Where? _mode;

  static String _ago(AppLocalizations l, DateTime at, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
    return switch (days) {
      <= 0 => l.today,
      1 => l.yesterday,
      _ => l.daysAgo(days),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final d = _delivery;
    final showErrors = widget.showErrors;
    final known = _known(ref.watch(recipientsProvider).value ?? const []);
    final where = _where(known);
    void choose(_Where mode) {
      FocusScope.of(context).unfocus();
      setState(() => _mode = mode);
      switch (mode) {
        case _Where.known:
          widget.draft.update(
            (d) => d
              ..dropoff = known!.lastAddress
              ..link = null,
          );
        case _Where.map:
          widget.onPlaceOnMap();
        case _Where.ask:
          widget.draft.update((d) => d.dropoff = null);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepHeading(title: l.recipientTitle, body: l.recipientBody),
        const SizedBox(height: 10),
        BoxedField(
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
        const SizedBox(height: 10),
        BoxedField(
          label: l.recipientPhone,
          hint: l.phoneHint,
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [PhoneInputFormatter()],
          trailing: Semantics(
            button: true,
            label: l.pickFromContacts,
            excludeSemantics: true,
            child: Squish(
              child: GestureDetector(
                key: recipientContactsKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_pickContact()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 177, 92, .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: TaraIcon(TaraIcons.users, size: 20, color: c.accentText),
                ),
              ),
            ),
          ),
        ),
        if (showErrors && !isCameroonMobile(d.recipientPhone)) ...[
          const SizedBox(height: 6),
          ErrorLine(l.phoneInvalid),
        ],
        const SizedBox(height: 14),
        Text(
          l.whereToDeliverQ,
          style: TaraText.label.copyWith(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (known != null) ...[
          AddressChoice(
            icon: TaraIcons.check,
            title: l.knownAddress,
            subtitle: known.lastOrderAt == null
                ? known.lastAddress.summary
                : l.lastDeliveryTo(_firstName(known.name), _ago(l, known.lastOrderAt!.toLocal(), DateTime.now())),
            selected: where == _Where.known,
            onTap: () => choose(_Where.known),
          ),
          const SizedBox(height: 10),
        ],
        AddressChoice(
          icon: TaraIcons.mapPin,
          title: l.placePointOnMap,
          subtitle: l.placePointOnMapBody,
          selected: where == _Where.map,
          onTap: () => choose(_Where.map),
        ),
        const SizedBox(height: 10),
        AddressChoice(
          icon: TaraIcons.link,
          title: l.askRecipient,
          subtitle: l.askRecipientShort,
          selected: where == _Where.ask,
          onTap: () => choose(_Where.ask),
        ),
        if (where == _Where.ask) ...[
          const SizedBox(height: 10),
          if (d.link case final link?)
            _LinkCard(
              link: link,
              name: _firstName(d.recipientName),
              sending: _sending,
              onWhatsapp: () => unawaited(_ask(whatsapp: true)),
              onSms: () => unawaited(_ask(whatsapp: false)),
              onPlaceMyself: widget.onPlaceOnMap,
            )
          else
            Row(
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
        ],
        if (d.dropoff case final address?) ...[
          const SizedBox(height: 10),
          _PlacedAddress(
            address: address,
            fromRecipient: d.link?.address?.id == address.id,
            onTap: widget.onPlaceOnMap,
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

enum _Where { known, map, ask }

/// Clé du bouton contacts du numéro (tests).
const recipientContactsKey = ValueKey('recipient-contacts');

/// Adresse de livraison retenue (maquette) : vignette de façade, lieu en gras, qui l'a
/// placée en vert (photo, note vocale, confirmation par une livraison).
class _PlacedAddress extends StatelessWidget {
  const _PlacedAddress({required this.address, required this.fromRecipient, required this.onTap});
  final Address address;
  final bool fromRecipient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final by = fromRecipient || address.source == 'LOCATION_LINK' ? l.addressFromRecipient : l.placedByYou;
    final extras = switch ((address.hasPhoto, address.hasVoiceNote)) {
      (true, true) => l.withPhotoAndVoice,
      (true, false) => l.withPhoto,
      (false, true) => l.withVoice,
      _ => null,
    };
    final detail = [by, ?extras, if (address.verified) l.addressVerifiedShort].join(' · ');
    final place = [
      [address.landmark, ?address.neighborhood?.name].join(', '),
    ].join();
    return Semantics(
      button: true,
      label: '$place, $detail',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: boxedFieldFill(c),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: boxedFieldBorder(c)),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 28, offset: Offset(0, 12)),
            ],
          ),
          child: Row(
            children: [
              // Vignette « façade » des maquettes : mur sombre, porte bleue, fenêtre.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment(-.35, -1),
                    end: Alignment(.35, 1),
                    colors: [Color(0xFF3A4A5C), Color(0xFF1E2732)],
                    stops: [0, .6],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 10,
                      child: Container(width: 22, height: 20, color: const Color(0xFF2F6FB3)),
                    ),
                    Positioned(
                      left: 32,
                      top: 16,
                      child: Container(width: 12, height: 14, color: const Color(0xFFC9A27A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: TaraText.small.copyWith(color: c.success, fontSize: 12)),
                  ],
                ),
              ),
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
