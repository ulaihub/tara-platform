import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/scoped_page.dart';
import '../order/address_editor.dart';
import '../order/pickup_step.dart';
import '../order/recipient_step.dart';
import 'bulk_draft.dart';
import 'bulk_send_screen.dart';
import 'contacts_screen.dart';
import 'line_editor.dart';
import 'paste_screen.dart';

/// Liste d'envoi en cours, gardée (chiffrée) sur le téléphone : l'accueil affiche combien
/// de clients y attendent.
final bulkDraftCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final draft = await BulkDraftStore(ref.read(keyValueStoreProvider), userId).load();
  return draft.lines.length;
});

/// Envoi en masse (C4) · liste d'envoi : jusqu'à 100 clients depuis le même point, réglages
/// communs, ajout par liste collée, contacts ou saisie ; chaque client numéroté.
class BulkScreen extends ConsumerStatefulWidget {
  const BulkScreen({super.key, required this.me, required this.onClose, this.onTrack, this.now});

  final Me me;
  final VoidCallback onClose;

  /// Ouvre le suivi d'une commande (après l'envoi).
  final ValueChanged<String>? onTrack;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<BulkScreen> createState() => _BulkScreenState();
}

class _BulkScreenState extends ConsumerState<BulkScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 280, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.85), size: 220, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  late final BulkDraftStore _store = BulkDraftStore(ref.read(keyValueStoreProvider), widget.me.id);
  BulkDraft? _draft;
  Timer? _saveTimer;

  /// « 3 clients ajoutés », affiché quelques secondes après un ajout.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final draft = await _store.load();
    if (!mounted) return;
    draft.addListener(_changed);
    setState(() => _draft = draft);
  }

  /// Chaque changement est gardé sur le téléphone (une fois la saisie posée).
  void _changed() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
    if (mounted) setState(() {});
  }

  void _save() {
    final draft = _draft;
    if (draft == null) return;
    unawaited(_store.save(draft).then((_) => ref.invalidate(bulkDraftCountProvider(widget.me.id))));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _toastTimer?.cancel();
    final draft = _draft;
    if (draft != null) {
      unawaited(_store.save(draft));
      draft
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }

  void _showAdded(int count) {
    _toastTimer?.cancel();
    setState(() => _toast = AppLocalizations.of(context).bulkAdded(count));
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// Clients connus (adresse de leur dernière commande), pour retrouver une adresse à
  /// partir d'un numéro.
  Future<Map<String, Recipient>> _known() async {
    final recipients = await ref.read(recipientsProvider.future).catchError((_) => <Recipient>[]);
    return {for (final r in recipients) digitsOf(r.phone).replaceFirst(RegExp('^237'), ''): r};
  }

  Future<void> _paste() async {
    final draft = _draft!;
    final known = await _known();
    if (!mounted) return;
    final lines = await Navigator.of(context)
        .push<List<BulkLine>>(scopedPage(context, (_) => PasteScreen(room: draft.room, known: known)));
    if (lines == null || !mounted) return;
    _showAdded(draft.addAll(lines));
  }

  Future<void> _contacts() async {
    final draft = _draft!;
    final lines = await Navigator.of(context).push<List<BulkLine>>(
      scopedPage(context, (_) => ContactsScreen(room: draft.room, already: {for (final l in draft.lines) l.phone})),
    );
    if (lines == null || !mounted) return;
    _showAdded(draft.addAll(lines));
  }

  Future<void> _edit(BulkLine? line) async {
    final draft = _draft!;
    final known = await _known();
    if (!mounted) return;
    // Numéro que le colis aura à l'envoi (un client à compléter : celui qu'il aura une fois
    // complété).
    final number = line == null
        ? draft.sendable.length + 1
        : draft.lines.takeWhile((l) => l != line).where((l) => l.state != LineState.incomplete).length + 1;
    final result = await Navigator.of(context).push<LineEdit>(
      scopedPage(
        context,
        (_) => LineEditor(
          line: line,
          number: number,
          defaultSize: draft.defaultSize,
          merchant: widget.me.merchant != null,
          known: known,
        ),
      ),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case LineSaved(:final line) when draft.lines.any((l) => l.key == line.key):
        draft.touch();
      case LineSaved(:final line):
        draft.addAll([line]);
      case LineRemoved(:final key):
        draft.remove(key);
    }
  }

  Future<void> _choosePickup() async {
    final l = AppLocalizations.of(context);
    final draft = _draft!;
    final addresses = await ref.read(pickupAddressesProvider.future).catchError((_) => <Address>[]);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PickupSheet(addresses: addresses, current: draft.pickup),
    );
    if (!mounted || chosen == null) return;
    if (chosen is Address) {
      draft.pickup = chosen;
      return;
    }
    // Nouvelle adresse placée sur la carte.
    final navigator = Navigator.of(context);
    final address = await navigator.push<Address>(
      scopedPage(
        context,
        (_) => AddressEditor(
          title: l.pickupAddressTitle,
          forPickup: true,
          onBack: navigator.pop,
          onSaved: navigator.pop,
          initial: switch (draft.pickup) {
            final current? => MapPoint(current.latitude, current.longitude),
            null => null,
          },
        ),
      ),
    );
    if (address == null || !mounted) return;
    ref.invalidate(pickupAddressesProvider);
    draft.pickup = address;
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final draft = _draft!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.bulkClearConfirm(draft.lines.length)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.bulkClearAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    draft.lines.clear();
    draft.touch();
  }

  Future<void> _review() async {
    final draft = _draft!;
    final done = await Navigator.of(context).push<bool>(
      scopedPage(context, (_) => BulkSendScreen(draft: draft, me: widget.me, onTrack: widget.onTrack, now: widget.now)),
    );
    if (done == true && mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final draft = _draft;
    // Une seule adresse d'enlèvement, ou la boutique d'un marchand : choisie d'office.
    final pickups = ref.watch(pickupAddressesProvider).value;
    if (draft != null && draft.pickup == null && pickups != null && pickups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => draft.pickup ??= pickups.first);
    }
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                child: Row(
                  children: [
                    GlassIconButton(icon: TaraIcons.close, label: l.close, onPressed: widget.onClose),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(l.bulkTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                          ),
                          if (draft != null)
                            Text(
                              l.bulkCount(draft.lines.length),
                              style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: draft == null
                    ? const SizedBox.shrink()
                    : ScrollWithFooter(
                        horizontal: 20,
                        top: 16,
                        content: [
                          _Settings(draft: draft, onPickup: () => unawaited(_choosePickup())),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final (i, (label, icon, action)) in [
                                (l.bulkAddPaste, TaraIcons.clipboard, _paste),
                                (l.bulkAddContacts, TaraIcons.users, _contacts),
                                (l.bulkAddManual, TaraIcons.plus, () => _edit(null)),
                              ].indexed) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _AddTile(
                                    label: label,
                                    icon: icon,
                                    onTap: draft.room > 0 ? () => unawaited(action()) : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (draft.room == 0) ...[
                            const SizedBox(height: 8),
                            Text(l.bulkFull, style: TaraText.small.copyWith(color: c.textTertiary)),
                          ],
                          const SizedBox(height: 14),
                          if (draft.lines.isEmpty)
                            _Empty()
                          else ...[
                            GlassCard(
                              radius: 22,
                              shadow: false,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Column(
                                children: [
                                  for (final (i, line) in draft.lines.indexed) ...[
                                    if (i > 0) Divider(height: 1, color: c.glassBorder),
                                    BulkLineRow(
                                      // Numéro du colis à l'envoi : les clients à compléter n'en ont pas.
                                      number: line.state == LineState.incomplete
                                          ? null
                                          : draft.sendable.indexOf(line) + 1,
                                      line: line,
                                      defaultSize: draft.defaultSize,
                                      onTap: () => unawaited(_edit(line)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TaraLink(label: l.bulkClear, onPressed: () => unawaited(_clear())),
                              ),
                            ),
                          ],
                        ],
                        footer: PrimaryButton(
                          label: l.bulkReview(draft.sendable.length),
                          icon: TaraIcons.arrowRight,
                          onPressed: draft.pickup != null && draft.sendable.isNotEmpty
                              ? () => unawaited(_review())
                              : null,
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 70,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _toast == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        liveRegion: true,
                        child: Center(
                          key: ValueKey(_toast),
                          child: InfoPill(label: _toast!, tone: TintTone.success, icon: TaraIcons.check),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Pour tous les colis » : départ, quand, taille par défaut.
class _Settings extends StatelessWidget {
  const _Settings({required this.draft, required this.onPickup});

  final BulkDraft draft;
  final VoidCallback onPickup;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final pickup = draft.pickup;
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.bulkSettings.toUpperCase(), style: TaraText.overline.copyWith(color: c.accentText)),
          const SizedBox(height: 8),
          AddressChoice(
            icon: TaraIcons.package,
            title: pickup?.label ?? (pickup == null ? l.bulkPickupMissing : l.stepPickup),
            subtitle: [if (pickup != null) pickup.summary, l.bulkWhenNow].join('\n'),
            selected: false,
            onTap: onPickup,
          ),
          const SizedBox(height: 12),
          Text(l.bulkDefaultSize, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          ChoiceChips<String>(
            columns: 4,
            options: [for (final size in BulkDraft.sizes) ChoiceOption(size, size)],
            selected: draft.defaultSize,
            onSelected: (size) {
              HapticFeedback.selectionClick();
              draft
                ..defaultSize = size
                ..touch();
            },
          ),
        ],
      ),
    );
  }
}

/// Une façon d'ajouter des clients : grande icône, mot dessous (lisible même en grand texte).
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.icon, required this.onTap});

  final String label;
  final TaraIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .5 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: GlassCard(
            radius: 20,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            child: Column(
              children: [
                IconTile(icon: icon, size: 40, radius: 13),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        children: [
          const IconTile(icon: TaraIcons.users, size: 52, radius: 18),
          const SizedBox(height: 12),
          Text(l.bulkEmptyTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            l.bulkEmptyBody,
            textAlign: TextAlign.center,
            style: TaraText.small.copyWith(color: c.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Un client de la liste : son numéro (à écrire sur le colis), son nom, où il en est.
class BulkLineRow extends StatelessWidget {
  const BulkLineRow({
    super.key,
    required this.number,
    required this.line,
    required this.defaultSize,
    this.onTap,
    this.trailing,
  });

  /// Numéro du colis à l'envoi ; null pour un client à compléter (« ! »).
  final int? number;
  final BulkLine line;
  final String defaultSize;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final state = line.state;
    final problem = !line.validPhone
        ? (line.rawPhone != null ? l.bulkPhoneIncomplete(line.rawPhone!) : l.bulkPhoneMissing)
        : !line.validName
        ? l.bulkNameMissing
        : null;
    final status = switch (state) {
      LineState.ready => line.dropoff!.summary,
      LineState.waiting => [if (line.hint.isNotEmpty) line.hint, l.bulkLineWaiting].join(' · '),
      LineState.incomplete => '${l.bulkLineIncomplete} : ${problem ?? ''}',
    };
    final size = line.size ?? defaultSize;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: state == LineState.ready ? TaraBrand.gradient : null,
                  color: state == LineState.incomplete ? c.dangerTint : (state == LineState.waiting ? c.glass : null),
                  border: state == LineState.waiting ? Border.all(color: TaraBrand.focusBorder, width: 1.5) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  number == null ? '!' : '$number',
                  style: TaraText.cardTitle.copyWith(
                    color: state == LineState.ready
                        ? TaraBrand.onBrand
                        : state == LineState.incomplete
                        ? c.dangerText
                        : c.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (line.name.trim().isNotEmpty) line.name.trim() else '—',
                        if (line.validPhone) displayPhone(line.phone),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TaraText.small.copyWith(
                        color: state == LineState.incomplete ? c.dangerText : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (line.codAmount > 0)
                        Text(
                          '${formatAmount(line.codAmount)} F',
                          style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      Text(size == 'BULKY' ? l.sizeBulky : size, style: TaraText.small.copyWith(color: c.textTertiary)),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Départ de l'envoi : une adresse enregistrée, ou une nouvelle sur la carte (renvoie
/// `true`).
class _PickupSheet extends StatelessWidget {
  const _PickupSheet({required this.addresses, required this.current});

  final List<Address> addresses;
  final Address? current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return SafeArea(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.pickupAddressTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 12),
            for (final address in addresses) ...[
              AddressChoice(
                icon: TaraIcons.package,
                title: address.label ?? l.stepPickup,
                subtitle: address.summary,
                selected: address.id == current?.id,
                onTap: () => Navigator.of(context).pop(address),
              ),
              const SizedBox(height: 8),
            ],
            GlassButton(
              label: l.linePlaceOnMap,
              icon: TaraIcons.mapPin,
              color: c.accentText,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
