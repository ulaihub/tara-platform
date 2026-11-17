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

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../order/address_editor.dart';
import '../order/pickup_step.dart';
import 'bulk_draft.dart';

/// Ce que l'expéditeur a fait d'un client : enregistré, ou retiré de la liste.
sealed class LineEdit {
  const LineEdit();
}

class LineSaved extends LineEdit {
  const LineSaved(this.line);
  final BulkLine line;
}

class LineRemoved extends LineEdit {
  const LineRemoved(this.key);
  final String key;
}

/// Un client de la liste d'envoi : nom, numéro, adresse (connue, placée sur la carte, ou
/// demandée au client par lien), colis, montant à encaisser.
class LineEditor extends ConsumerStatefulWidget {
  const LineEditor({
    super.key,
    required this.line,
    required this.number,
    required this.defaultSize,
    required this.merchant,
    required this.known,
  });

  /// Client modifié ; null pour en saisir un nouveau.
  final BulkLine? line;

  /// Son numéro dans la liste.
  final int number;
  final String defaultSize;
  final bool merchant;

  /// Clients connus, par numéro national : leur dernière adresse est proposée.
  final Map<String, Recipient> known;

  @override
  ConsumerState<LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<LineEditor> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.25, -1.05), size: 240, colors: BlobSpec.brand, blur: 70)];

  /// Copie de travail : la ligne de la liste ne change qu'à l'enregistrement.
  late final BulkLine _line = widget.line == null ? BulkLine() : BulkLine.fromJson(widget.line!.toJson());
  late final _name = TextEditingController(text: _line.name);
  late final _phone = TextEditingController(text: _line.validPhone ? displayPhone(_line.phone) : '');
  late final _description = TextEditingController(text: _line.description);
  late final _cod = TextEditingController(text: _line.codAmount == 0 ? '' : formatAmount(_line.codAmount));
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _line.name = _name.text));
    _phone.addListener(() => setState(() => _line.phone = digitsOf(_phone.text)));
    _description.addListener(() => _line.description = _description.text);
    _cod.addListener(() => setState(() => _line.codAmount = AmountInputFormatter.valueOf(_cod.text) ?? 0));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _description.dispose();
    _cod.dispose();
    super.dispose();
  }

  Recipient? get _knownRecipient => widget.known[_line.phone];

  Future<void> _placeOnMap() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final address = await navigator.push<Address>(
      scopedPage(
        context,
        (_) => AddressEditor(
          title: l.deliveryAddress,
          contactName: _line.name.trim().isEmpty ? null : _line.name.trim(),
          contactPhone: _line.validPhone ? '+237${_line.phone}' : null,
          initial: switch (_line.dropoff) {
            final current? => MapPoint(current.latitude, current.longitude),
            null => null,
          },
          onBack: navigator.pop,
          onSaved: navigator.pop,
        ),
      ),
    );
    if (address == null || !mounted) return;
    setState(() => _line.dropoff = address);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_line.validName || !_line.validPhone || _line.codAmount > BulkLine.maxCod) {
      setState(() => _tried = true);
      return;
    }
    _line.rawPhone = null;
    final original = widget.line;
    if (original == null) {
      Navigator.of(context).pop(LineSaved(_line));
      return;
    }
    // Les changements passent sur la ligne de la liste (même clé, même place).
    original
      ..name = _line.name.trim()
      ..phone = _line.phone
      ..rawPhone = null
      ..dropoff = _line.dropoff
      ..size = _line.size
      ..description = _line.description
      ..codAmount = _line.codAmount
      ..fragile = _line.fragile;
    Navigator.of(context).pop(LineSaved(original));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final known = _knownRecipient;
    final dropoff = _line.dropoff;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary)),
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
                GlassIconButton(
                  icon: TaraIcons.chevronLeft,
                  label: l.back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.line == null ? l.lineNew : l.lineTitle(widget.number),
                      style: TaraText.titleForm.copyWith(color: c.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScrollWithFooter(
              horizontal: 20,
              top: 18,
              content: [
                TaraTextField(
                  label: l.recipientName,
                  hint: l.recipientNameHint,
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                ),
                if (_tried && !_line.validName) ...[const SizedBox(height: 6), ErrorLine(l.recipientNameRequired)],
                const SizedBox(height: 12),
                TaraTextField(
                  label: l.recipientPhone,
                  hint: l.phoneHint,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneInputFormatter()],
                  leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
                ),
                if (_line.rawPhone != null && !_line.validPhone) ...[
                  const SizedBox(height: 6),
                  ErrorLine(l.bulkPhoneIncomplete(_line.rawPhone!)),
                ] else if (_tried && !_line.validPhone) ...[
                  const SizedBox(height: 6),
                  ErrorLine(l.phoneInvalid),
                ],
                const SizedBox(height: 20),
                label(l.deliveryAddress),
                if (_line.hint.isNotEmpty) ...[
                  Text(l.lineHintNoted(_line.hint), style: TaraText.small.copyWith(color: c.textTertiary)),
                  const SizedBox(height: 8),
                ],
                AddressChoice(
                  icon: TaraIcons.send,
                  title: l.lineAskLink,
                  subtitle: l.lineAskLinkBody,
                  selected: dropoff == null,
                  onTap: () => setState(() => _line.dropoff = null),
                ),
                if (known != null) ...[
                  const SizedBox(height: 8),
                  AddressChoice(
                    icon: TaraIcons.mapPin,
                    title: l.lineLastAddress,
                    subtitle: known.lastAddress.summary,
                    selected: dropoff?.id == known.lastAddress.id,
                    onTap: () => setState(() => _line.dropoff = known.lastAddress),
                  ),
                ],
                if (dropoff != null && dropoff.id != known?.lastAddress.id) ...[
                  const SizedBox(height: 8),
                  AddressChoice(
                    icon: TaraIcons.mapPin,
                    title: dropoff.neighborhood?.name ?? l.deliveryAddress,
                    subtitle: dropoff.landmark,
                    selected: true,
                    onTap: () => unawaited(_placeOnMap()),
                  ),
                ],
                const SizedBox(height: 8),
                GlassButton(
                  label: l.linePlaceOnMap,
                  icon: TaraIcons.mapPin,
                  color: c.accentText,
                  onPressed: () => unawaited(_placeOnMap()),
                ),
                const SizedBox(height: 20),
                label(l.lineSize),
                ChoiceChips<String>(
                  columns: 3,
                  options: [
                    ChoiceOption('', l.lineSizeDefault(widget.defaultSize)),
                    for (final size in BulkDraft.sizes) ChoiceOption(size, size),
                    ChoiceOption('BULKY', l.sizeBulky),
                  ],
                  selected: _line.size ?? '',
                  onSelected: (size) {
                    HapticFeedback.selectionClick();
                    setState(() => _line.size = size.isEmpty ? null : size);
                  },
                ),
                const SizedBox(height: 16),
                TaraTextField(
                  label: l.lineDescription,
                  hint: l.lineDescriptionHint,
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                ),
                if (widget.merchant) ...[
                  const SizedBox(height: 14),
                  TaraTextField(
                    label: l.codLabel,
                    hint: l.codHint,
                    controller: _cod,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AmountInputFormatter(maxDigits: 7)],
                  ),
                  if (_line.codAmount > BulkLine.maxCod) ...[const SizedBox(height: 6), ErrorLine(l.codTooHigh)],
                  const SizedBox(height: 6),
                  Text(l.codHelp, style: TaraText.small.copyWith(color: c.textTertiary)),
                ],
                const SizedBox(height: 14),
                GlassCard(
                  radius: 18,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.fragileTitle,
                          style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      GlassSwitch(
                        value: _line.fragile,
                        semanticLabel: l.fragileTitle,
                        onChanged: (value) => setState(() => _line.fragile = value),
                      ),
                    ],
                  ),
                ),
                if (widget.line != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TaraLink(
                      label: l.lineRemove,
                      onPressed: () => Navigator.of(context).pop(LineRemoved(widget.line!.key)),
                    ),
                  ),
                ],
              ],
              footer: PrimaryButton(label: l.lineSave, icon: TaraIcons.check, onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }
}
