import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/check_row.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../order/recipient_step.dart';
import 'bulk_draft.dart';
import 'phone_contacts.dart';

enum _Access { unknown, loading, granted, denied }

/// Envoi en masse · choisir des clients : vos clients (adresse déjà connue) et les contacts
/// du téléphone, à cocher. Seuls les clients cochés quittent le téléphone.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key, required this.room, required this.already});

  /// Places encore libres dans la liste.
  final int room;

  /// Numéros déjà dans la liste : ils ne sont pas reproposés.
  final Set<String> already;

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.25, -1.05), size: 240, colors: BlobSpec.brand, blur: 70)];

  /// Au plus ce nombre de contacts affichés : la recherche affine.
  static const _shown = 200;

  final _search = TextEditingController();
  final _selected = <String, BulkLine>{};
  _Access _access = _Access.unknown;
  List<PhoneContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = ref.read(phoneContactsProvider);
    setState(() => _access = _Access.loading);
    try {
      if (!await contacts.request()) {
        if (mounted) setState(() => _access = _Access.denied);
        return;
      }
      final list = await contacts.mobiles();
      if (mounted) {
        setState(() {
          _contacts = list;
          _access = _Access.granted;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _access = _Access.denied);
    }
  }

  String _national(String phone) => digitsOf(phone).replaceFirst(RegExp('^237'), '');

  bool _matches(String name, String phone) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final digits = digitsOf(query);
    return name.toLowerCase().contains(query) || (digits.isNotEmpty && phone.contains(digits));
  }

  void _toggle(String phone, BulkLine Function() line, bool on) {
    setState(() {
      if (on) {
        if (_selected.length < widget.room) _selected[phone] = line();
      } else {
        _selected.remove(phone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final recipients = ref.watch(recipientsProvider).value ?? const <Recipient>[];
    final knownPhones = {for (final r in recipients) _national(r.phone)};
    final known = [
      for (final r in recipients)
        if (!widget.already.contains(_national(r.phone)) && _matches(r.name, _national(r.phone))) r,
    ];
    final contacts = [
      for (final contact in _contacts)
        if (!widget.already.contains(contact.phone) &&
            !knownPhones.contains(contact.phone) &&
            _matches(contact.name, contact.phone))
          contact,
    ];
    final full = _selected.length >= widget.room;

    Widget check(String phone, String name, String detail, BulkLine Function() line) {
      final on = _selected.containsKey(phone);
      return TaraCheckRow(
        value: on,
        onChanged: on || !full ? (value) => _toggle(phone, line, value) : null,
        label: TextSpan(
          children: [
            TextSpan(
              text: name,
              style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: '\n$detail',
              style: TaraText.small.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      );
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(title.toUpperCase(), style: TaraText.overline.copyWith(color: c.accentText)),
    );

    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
            child: Row(
              children: [
                GlassIconButton(icon: TaraIcons.close, label: l.close, onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.contactsTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScrollWithFooter(
              horizontal: 20,
              top: 14,
              content: [
                TaraTextField(
                  hint: l.contactsSearch,
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: TaraIcon(TaraIcons.search, size: 18),
                  ),
                ),
                if (known.isNotEmpty) ...[
                  section(l.contactsKnown),
                  GlassCard(
                    radius: 20,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (final r in known)
                          check(
                            _national(r.phone),
                            r.name,
                            [
                              r.lastAddress.neighborhood?.name ?? r.lastAddress.landmark,
                              l.contactsOrders(r.ordersCount),
                            ].join(' · '),
                            () => BulkLine(name: r.name, phone: _national(r.phone), dropoff: r.lastAddress),
                          ),
                      ],
                    ),
                  ),
                ],
                section(l.contactsPhone),
                switch (_access) {
                  _Access.unknown => GlassCard(
                    radius: 20,
                    shadow: false,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.contactsAllowBody, style: TaraText.small.copyWith(color: c.textSecondary, height: 1.45)),
                        const SizedBox(height: 10),
                        GlassButton(
                          label: l.contactsAllow,
                          icon: TaraIcons.users,
                          color: c.accentText,
                          onPressed: () => unawaited(_loadContacts()),
                        ),
                      ],
                    ),
                  ),
                  _Access.loading => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: GooLoader(compact: true)),
                  ),
                  _Access.denied => GlassCard(
                    radius: 20,
                    shadow: false,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.contactsDenied, style: TaraText.small.copyWith(color: c.textSecondary)),
                        const SizedBox(height: 8),
                        TaraLink(
                          label: l.contactsOpenSettings,
                          onPressed: () => unawaited(ref.read(phoneContactsProvider).openSettings()),
                        ),
                      ],
                    ),
                  ),
                  _Access.granted when contacts.isEmpty => Text(
                    l.contactsEmpty,
                    style: TaraText.small.copyWith(color: c.textTertiary),
                  ),
                  _Access.granted => GlassCard(
                    radius: 20,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (final contact in contacts.take(_shown))
                          check(
                            contact.phone,
                            contact.name,
                            displayPhone(contact.phone),
                            () => BulkLine(name: contact.name, phone: contact.phone),
                          ),
                      ],
                    ),
                  ),
                },
                const SizedBox(height: 12),
                Text(l.contactsNote, style: TaraText.small.copyWith(color: c.textTertiary, height: 1.45)),
              ],
              footer: PrimaryButton(
                label: l.bulkAddCount(_selected.length),
                icon: TaraIcons.plus,
                onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.values.toList()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
