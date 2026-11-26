import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/motion_clock.dart';
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

  static String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

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
    Widget section(String text) => Text(
      text,
      style: TaraText.label.copyWith(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepHeading(title: l.whenTitle, body: l.whenBody),
        const SizedBox(height: 10),
        // Deux cartes côte à côte (maquette) : maintenant, ou programmer.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ModeCard(
                  icon: TaraIcons.bolt,
                  title: l.whenNow,
                  body: l.whenNowBody,
                  selected: !draft.later,
                  onTap: () => _setLater(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  icon: TaraIcons.calendar,
                  title: l.whenLater,
                  body: l.whenLaterBody,
                  selected: draft.later,
                  onTap: () => _setLater(true),
                ),
              ),
            ],
          ),
        ),
        if (!draft.later) const _Departing(),
        if (draft.later) ...[
          const SizedBox(height: 10),
          section(l.dayLabel),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              // Cinq jours visibles, les suivants en faisant glisser.
              final width = (constraints.maxWidth - 4 * 6) / 5;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final (i, day) in days.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      SizedBox(
                        width: width,
                        child: _DayChip(
                          top: switch (day.difference(today).inDays) {
                            0 => l.dayTodayShort,
                            1 => l.dayTomorrowShort,
                            _ => _capitalized(DateFormat.E(locale).format(day)),
                          },
                          number: '${day.day}',
                          semanticLabel: dayLabel(day),
                          selected: _sameDay(day, _day),
                          onTap: () => _chooseDay(day),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          section(l.timeLabel),
          const SizedBox(height: 10),
          ChoiceChips<DateTime>(
            columns: 4,
            height: 40,
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

/// « Maintenant » ou « Programmer » : tuile d'icône (orange quand choisie), titre, phrase.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final TaraIconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: Squish(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 132),
            padding: EdgeInsets.all(selected ? 13 : 14),
            decoration: BoxDecoration(
              color: selected ? const Color.fromRGBO(255, 138, 0, .10) : boxedFieldFill(c),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? const Color(0xFFFF8A00) : boxedFieldBorder(c),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: selected ? TaraBrand.gradient : null,
                    color: selected ? null : const Color.fromRGBO(255, 177, 92, .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: TaraIcon(icon, size: 20, color: selected ? TaraBrand.onBrand : c.accentText),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(body, style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Maintenant » : le colis 3D file, traits de vitesse derrière lui (maquette).
class _Departing extends StatelessWidget {
  const _Departing();

  @override
  Widget build(BuildContext context) {
    const lines = [
      (20.0, 60.0, TaraBrand.amber, 600),
      (38.0, 44.0, TaraBrand.orange, 750),
      (56.0, 28.0, TaraBrand.red, 900),
    ];
    return ExcludeSemantics(
      child: SizedBox(
        height: 170,
        child: Center(
          child: SizedBox.square(
            dimension: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: OverflowBox(
                    maxWidth: 200,
                    maxHeight: 200,
                    child: Parcel3D(
                      size: 96,
                      shadow: false,
                      period: Duration(seconds: 5),
                      bobPeriod: Duration(milliseconds: 1600),
                    ),
                  ),
                ),
                for (final (top, width, color, ms) in lines)
                  Positioned(
                    top: top,
                    right: 96 + 10,
                    child: MotionBuilder(
                      period: Duration(milliseconds: ms),
                      builder: (context, t, child) =>
                          Transform.translate(offset: Offset(3 - 3 * math.cos(t * 2 * math.pi), 0), child: child),
                      child: Container(
                        width: width,
                        height: 7,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Jour proposé (maquette) : jour court au-dessus, numéro en gras ; orange une fois choisi.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.top,
    required this.number,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String number;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final ink = selected ? TaraBrand.onBrand : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Squish(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              gradient: selected ? TaraBrand.gradient : null,
              color: selected ? null : boxedFieldFill(c),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? const Color(0xFFFF8A00) : boxedFieldBorder(c)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    top,
                    maxLines: 1,
                    style: TaraText.small.copyWith(
                      color: ink.withValues(alpha: .75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: TaraText.text.copyWith(color: ink, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
