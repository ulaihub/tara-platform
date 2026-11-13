import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../core/location.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'address_media_section.dart';

/// Libellés proposés pour une adresse d'enlèvement.
const pickupLabels = ['SHOP', 'HOME', 'OFFICE'];

/// Liste des quartiers de Douala (gardée le temps de la session).
final neighborhoodsProvider = FutureProvider<List<Neighborhood>>((ref) => ref.read(clientApiProvider).neighborhoods());

/// Saisie d'une adresse (B1, non dessinée : style Tara) : la carte glisse sous l'épingle,
/// « Ma position » la centre sur le téléphone ; quartier choisi dans la liste (déduit du point
/// sinon) et repère écrit obligatoire. Pour un enlèvement, un libellé (Boutique, Maison…).
class AddressEditor extends ConsumerStatefulWidget {
  const AddressEditor({
    super.key,
    required this.title,
    required this.onBack,
    required this.onSaved,
    this.forPickup = false,
    this.contactName,
    this.contactPhone,
    this.initial,
  });

  final String title;
  final VoidCallback onBack;
  final ValueChanged<Address> onSaved;
  final bool forPickup;

  /// Destinataire, enregistré avec l'adresse de livraison.
  final String? contactName;
  final String? contactPhone;

  /// Point de départ de la carte (Douala par défaut).
  final MapPoint? initial;

  @override
  ConsumerState<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends ConsumerState<AddressEditor> {
  final _map = PinPickerHandle();
  final _landmark = TextEditingController();
  final _media = AddressMedia();
  late MapPoint _point = widget.initial ?? MapPoint.douala;
  Neighborhood? _neighborhood;

  /// Ce que l'API dit du point sous l'épingle (quartier, zone desservie) ; null pendant la
  /// lecture. [_placeSeq] écarte une réponse arrivée après un nouveau déplacement.
  PointLocation? _place;
  int _placeSeq = 0;
  String? _label;
  bool _locating = false;
  bool _saving = false;
  bool _tried = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.forPickup) _label = pickupLabels.first;
    _landmark.addListener(() => setState(() => _error = null));
    if (widget.initial == null) unawaited(_locate());
    unawaited(_lookUp(_point));
  }

  /// Quartier du point et zone desservie, lus dès que la carte s'arrête.
  Future<void> _lookUp(MapPoint point) async {
    final seq = ++_placeSeq;
    setState(() => _place = null);
    try {
      final place = await ref.read(clientApiProvider).locate(point.latitude, point.longitude);
      if (mounted && seq == _placeSeq) setState(() => _place = place);
    } catch (_) {
      // Réseau : la bulle reste cachée, le quartier sera déduit à l'enregistrement.
    }
  }

  @override
  void dispose() {
    _landmark.dispose();
    _media.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final point = await ref.read(currentPositionProvider)();
    if (!mounted) return;
    setState(() => _locating = false);
    if (point == null) {
      setState(() => _error = AppLocalizations.of(context).locationUnavailable);
      return;
    }
    setState(() => _point = point);
    await _map.moveTo(point);
  }

  bool get _valid => _landmark.text.trim().length >= 3;

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_valid) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      // Photo et note vocale d'abord : l'adresse les référence (B2).
      final api = ref.read(clientApiProvider);
      final photo = _media.photo;
      final voice = _media.voice;
      final photoKey = photo == null ? null : await api.uploadMedia(photo, 'ADDRESS_PHOTO', mimeType: 'image/jpeg');
      final voiceNoteKey = voice == null ? null : await api.uploadMedia(voice, 'VOICE_NOTE', mimeType: 'audio/mp4');
      final address = await ref
          .read(clientApiProvider)
          .createAddress(
            latitude: _point.latitude,
            longitude: _point.longitude,
            landmark: _landmark.text.trim(),
            neighborhoodId: _neighborhood?.id,
            label: _label == null ? null : labelText(l, _label!),
            contactName: widget.contactName,
            contactPhone: widget.contactPhone,
            photoKey: photoKey,
            voiceNoteKey: voiceNoteKey,
          );
      if (mounted) widget.onSaved(address);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseNeighborhood() async {
    final chosen = await showModalBottomSheet<Neighborhood>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      builder: (context) => const _NeighborhoodSheet(),
    );
    if (chosen != null && mounted) setState(() => _neighborhood = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final size = MediaQuery.sizeOf(context);
    // Panneau du bas : 58 % de l'écran au plus, la carte garde le reste.
    final panelHeight = size.height * .58;
    return TaraScreen(
      safeTop: false,
      safeBottom: false,
      background: Positioned.fill(
        child: PinPickerMap(
          initial: _point,
          handle: _map,
          real: ref.watch(realMapProvider),
          bottomPadding: panelHeight - 24,
          label: _PlaceBubble(place: _place),
          onChanged: (point) {
            setState(() => _point = point);
            unawaited(_lookUp(point));
          },
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: TaraIcons.chevronLeft,
                      label: l.back,
                      onPressed: _saving ? null : widget.onBack,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Semantics(
                          header: true,
                          child: Text(widget.title, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: panelHeight + 12,
            child: GlassIconButton(
              icon: TaraIcons.navigation,
              label: l.myPosition,
              size: 52,
              radius: 18,
              onPressed: _locating ? null : _locate,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: SheetPanel(
              child: ScrollWithFooter(
                horizontal: 20,
                top: 4,
                content: [
                  Text(l.pinHint, style: TaraText.small.copyWith(color: c.textTertiary)),
                  const SizedBox(height: 14),
                  Text(l.neighborhoodLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _chooseNeighborhood,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: c.inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.chipBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _neighborhood?.name ?? _place?.neighborhood?.name ?? l.neighborhoodAuto,
                              style: TaraText.body.copyWith(
                                color: (_neighborhood ?? _place?.neighborhood) == null ? c.placeholder : c.textPrimary,
                              ),
                            ),
                          ),
                          TaraIcon(TaraIcons.chevronDown, size: 20, color: c.textTertiary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TaraTextField(
                    label: l.landmarkLabel,
                    hint: l.landmarkHint,
                    controller: _landmark,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (_tried && !_valid) ...[const SizedBox(height: 6), ErrorLine(l.landmarkRequired)],
                  if (widget.forPickup) ...[
                    const SizedBox(height: 14),
                    Text(l.addressLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 8),
                    ChoiceChips<String>(
                      columns: 3,
                      options: [for (final code in pickupLabels) ChoiceOption(code, labelText(l, code))],
                      selected: _label,
                      onSelected: (value) => setState(() => _label = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AddressMediaSection(media: _media),
                  if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
                ],
                footer: PrimaryButton(label: l.saveAddress, icon: TaraIcons.check, loading: _saving, onPressed: _save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Libellé d'une adresse d'enlèvement dans la langue de l'app.
String labelText(AppLocalizations l, String code) => switch (code) {
  'SHOP' => l.labelShop,
  'HOME' => l.labelHome,
  _ => l.labelOffice,
};

/// Choix du quartier : recherche dans la liste, ou « Déduire du point ».
/// Bulle sous l'épingle : quartier du point, ou point hors de la zone desservie.
/// Rien pendant la lecture.
class _PlaceBubble extends StatelessWidget {
  const _PlaceBubble({required this.place});

  final PointLocation? place;

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    if (place == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final outside = !place.inServiceArea;
    final color = outside ? c.dangerText : c.textPrimary;
    return Semantics(
      liveRegion: true,
      child: GlassCard(
        radius: 14,
        fill: c.glassStrong,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaraIcon(
              outside ? TaraIcons.alertCircle : TaraIcons.mapPin,
              size: 16,
              color: outside ? color : c.accentText,
            ),
            const SizedBox(width: 6),
            Text(
              outside ? l.pinOutOfArea : place.neighborhood?.name ?? l.pinPlaced,
              style: TaraText.label.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeighborhoodSheet extends ConsumerStatefulWidget {
  const _NeighborhoodSheet();

  @override
  ConsumerState<_NeighborhoodSheet> createState() => _NeighborhoodSheetState();
}

class _NeighborhoodSheetState extends ConsumerState<_NeighborhoodSheet> {
  final _search = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final all = ref.watch(neighborhoodsProvider).value ?? const <Neighborhood>[];
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final n in all)
        if (query.isEmpty || n.name.toLowerCase().contains(query)) n,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: SheetPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.neighborhoodLabel, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),
              TaraTextField(hint: l.neighborhoodSearch, controller: _search, autofocus: true),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final n in shown)
                      ListRow(
                        leading: const IconTile(icon: TaraIcons.mapPin, size: 36, radius: 12),
                        title: n.name,
                        onTap: () => Navigator.of(context).pop(n),
                      ),
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

/// Panneau du bas en verre fort, de hauteur fixe : poignée puis contenu qui occupe le reste
/// (liste ou formulaire défilant).
class SheetPanel extends StatelessWidget {
  const SheetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      fill: c.glassStrong,
      padding: const EdgeInsets.only(top: 10),
      shadow: !c.isDark,
      blur: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
