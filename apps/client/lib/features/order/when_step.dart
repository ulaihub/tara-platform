import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';
import 'pickup_step.dart';

/// Règles du serveur (C3) : au moins 30 min d'avance, au plus 7 jours.
const minScheduleDelay = Duration(minutes: 30);
const maxScheduleDelay = Duration(days: 7);

/// Créneaux proposés : toutes les 30 min, de 6 h à 21 h 30 (heure du téléphone).
const _firstSlotMinutes = 6 * 60;
const _lastSlotMinutes = 21 * 60 + 30;

/// Supplément de nuit du serveur : de 20 h à 6 h.
bool isNightSlot(DateTime slot) => slot.hour >= 20 || slot.hour < 6;

/// Heures de passage possibles pour un jour donné, à partir de [now].
List<DateTime> scheduleSlots(DateTime day, DateTime now) {
  final earliest = now.add(minScheduleDelay);
  final latest = now.add(maxScheduleDelay);
  return [
    for (var m = _firstSlotMinutes; m <= _lastSlotMinutes; m += 30)
      DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
  ].where((slot) => !slot.isBefore(earliest) && !slot.isAfter(latest)).toList();
}

/// Jours qui ont encore au moins un créneau, d'aujourd'hui à J+7.
List<DateTime> scheduleDays(DateTime now) =>
    [for (var i = 0; i <= 7; i++) DateTime(now.year, now.month, now.day + i)]
        .where((day) => scheduleSlots(day, now).isNotEmpty)
        .toList();

/// « aujourd'hui à 14:30 », « demain à 09:00 », « samedi 7 novembre à 20:00 ».
String scheduleText(AppLocalizations l, String locale, DateTime slot, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (DateTime(slot.year, slot.month, slot.day).difference(today).inDays) {
    0 => l.todayAt(formatClock(slot)),
    1 => l.tomorrowAt(formatClock(slot)),
    _ => l.dateAt(DateFormat.MMMMEEEEd(locale).format(slot), formatClock(slot)),
  };
}

/// Étape 4 · Quand : tout de suite, ou programmée sur un créneau jusqu'à J+7.
class WhenStep extends StatefulWidget {
  const WhenStep({super.key, required this.draft, required this.showErrors, required this.now});

  final OrderDraft draft;
  final bool showErrors;

  /// Horloge (tests).
  final DateTime Function() now;

  @override
  State<WhenStep> createState() => _WhenStepState();
}

class _WhenStepState extends State<WhenStep> {
  late DateTime _day = _initialDay();

  DateTime _initialDay() {
    final chosen = widget.draft.scheduledFor;
    if (chosen != null) return DateTime(chosen.year, chosen.month, chosen.day);
    final days = scheduleDays(widget.now());
    return days.isEmpty ? DateTime.now() : days.first;
  }

  void _setLater(bool later) {
    HapticFeedback.selectionClick();
    widget.draft
      ..later = later
      ..touch();
  }

  void _chooseDay(DateTime day) {
    setState(() => _day = day);
    final chosen = widget.draft.scheduledFor;
    if (chosen != null && !_sameDay(chosen, day)) {
      widget.draft
        ..scheduledFor = null
        ..touch();
    }
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final draft = widget.draft;
    final now = widget.now();
    final today = DateTime(now.year, now.month, now.day);
    String dayLabel(DateTime day) => switch (day.difference(today).inDays) {
      0 => l.dayToday,
      1 => l.dayTomorrow,
      _ => DateFormat.MMMEd(locale).format(day),
    };
    final days = scheduleDays(now);
    final slots = scheduleSlots(_day, now);
    final chosen = draft.scheduledFor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.whenTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 8),
        Text(l.whenBody, style: TaraText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 18),
        AddressChoice(
          icon: TaraIcons.navigation,
          title: l.whenNow,
          subtitle: l.whenNowBody,
          selected: !draft.later,
          onTap: () => _setLater(false),
        ),
        const SizedBox(height: 10),
        AddressChoice(
          icon: TaraIcons.clock,
          title: l.whenLater,
          subtitle: l.whenLaterBody,
          selected: draft.later,
          onTap: () => _setLater(true),
        ),
        if (draft.later) ...[
          const SizedBox(height: 20),
          Text(l.dayLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final day in days) ...[
                  _DayChip(label: dayLabel(day), selected: _sameDay(day, _day), onTap: () => _chooseDay(day)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(l.timeLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          ChoiceChips<DateTime>(
            columns: 4,
            height: 44,
            options: [for (final slot in slots) ChoiceOption(slot, formatClock(slot))],
            selected: chosen,
            onSelected: (slot) => widget.draft
              ..scheduledFor = slot
              ..touch(),
          ),
          if (widget.showErrors && chosen == null) ...[const SizedBox(height: 6), ErrorLine(l.slotRequired)],
          const SizedBox(height: 12),
          if (chosen != null)
            InfoNote(
              icon: TaraIcons.clock,
              text: [
                l.scheduledSummary(scheduleText(l, locale, chosen, now)),
                if (isNightSlot(chosen)) l.nightSurcharge,
              ].join('\n'),
            )
          else if (slots.any(isNightSlot))
            Text(l.nightSurcharge, style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ],
    );
  }
}

/// Jour proposé : pastille de verre, orange une fois choisie.
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: selected ? c.chipSelected : null,
            color: selected ? null : c.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? c.chipSelectedBorder : c.glassBorder,
              width: selected ? c.chipSelectedBorderWidth : 1,
            ),
          ),
          child: Text(
            label,
            style: TaraText.label.copyWith(color: selected ? c.accentText : c.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
