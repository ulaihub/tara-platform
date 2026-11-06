import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../design/components/brand.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/inputs.dart';
import '../../design/components/layout.dart';
import '../../design/components/progress.dart';
import '../../design/components/status.dart';
import '../../design/format.dart';
import '../../design/motion/effects.dart';
import '../../design/motion/liquid_background.dart';
import '../../design/motion/liquid_wave.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_effects.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';

/// Catalogue des composants et des animations du socle visuel (passation §3 et §4).
///
/// Outil de développement : il sert aux captures de référence et à la revue visuelle,
/// il n'est pas accessible aux livreurs. Les intitulés des sections ne sont donc pas
/// traduits ; les libellés des composants viennent des fichiers de langue.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.scrollable = true});

  /// `false` : le catalogue prend toute sa hauteur (captures pleine longueur).
  final bool scrollable;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

enum _Pay { cash, mobileMoney }

enum _Period { day, week, month }

class _CatalogScreenState extends State<CatalogScreen> {
  _Pay _pay = _Pay.cash;
  _Period _period = _Period.week;
  int _tab = 0;
  bool _sosSent = false;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.4, -0.2), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 4)),
    BlobSpec(alignment: Alignment(1.2, 0.6), size: 260, colors: BlobSpec.soft, blur: 70, delay: Duration(seconds: 8)),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = <Widget>[
      _header(context, l),
      _section('Couleurs', _colors(context)),
      _section('Typographie', _typography(context)),
      _section('Boutons', _buttons(context, l)),
      _section('Saisie', _inputs(context, l)),
      _section('Progression', _progress(context, l)),
      _section('Statut', _status(context, l)),
      _section('Listes et cartes', _cards(context, l)),
      _section('Carte et repères', _map(context)),
      _section('Animations', _animations(context, l)),
      _section('Navigation', _navigation(context, l)),
    ];
    final content = widget.scrollable
        ? ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: sections)
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections,
            ),
          );
    return TaraScreen(blobs: _blobs, child: content);
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: _Overline(title)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _header(BuildContext context, AppLocalizations l) {
    final c = TaraColors.of(context);
    final settings = AppSettingsScope.maybeOf(context);
    final effects = TaraEffects.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: TaraLogo(width: 132)),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(l.catalogTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 6),
        Text(
          '${c.isDark ? 'Thème sombre' : 'Thème clair'} · '
          '${effects.reduced ? 'effets réduits' : 'effets complets'}'
          '${effects.reduceMotion ? ' · animations réduites' : ''}',
          style: TaraText.label.copyWith(color: c.textTertiary),
        ),
        if (settings != null) ...[
          const SizedBox(height: 16),
          LiquidSegmented<ThemeMode>(
            segments: const [(ThemeMode.system, 'Système'), (ThemeMode.light, 'Clair'), (ThemeMode.dark, 'Sombre')],
            selected: settings.themeMode,
            onChanged: (mode) => settings.themeMode = mode,
            compact: true,
          ),
          const SizedBox(height: 10),
          LiquidSegmented<EffectsPreference>(
            segments: const [
              (EffectsPreference.automatic, 'Auto'),
              (EffectsPreference.full, 'Complets'),
              (EffectsPreference.reduced, 'Réduits'),
            ],
            selected: settings.effects.preference,
            onChanged: (value) => setState(() => settings.effects.preference = value),
            compact: true,
          ),
        ],
      ],
    );
  }

  Widget _colors(BuildContext context) {
    final c = TaraColors.of(context);
    final swatches = <(String, Color)>[
      ('Fond', c.bg),
      ('Texte', c.textPrimary),
      ('Texte 2', c.textSecondary),
      ('Texte 3', c.textTertiary),
      ('Accent', c.accentText),
      ('Succès', c.success),
      ('Danger', c.dangerText),
      ('Alerte', c.warningText),
      ('En ligne', c.online),
      ('Hors ligne', c.offline),
      ('SOS', TaraBrand.sos),
      ('Sur marque', TaraBrand.onBrand),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(18)),
          child: Text('#FFB000 → #FF6A00 → #FF3D00', style: TaraText.label.copyWith(color: TaraBrand.onBrand)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [for (final (name, color) in swatches) _Swatch(name: name, color: color)],
        ),
      ],
    );
  }

  Widget _typography(BuildContext context) {
    final c = TaraColors.of(context);
    Text sample(String text, TextStyle style, [Color? color]) =>
        Text(text, style: style.copyWith(color: color ?? c.textPrimary));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              sample('18', TaraText.giantNumber),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: sample('Sora 72 · chiffres tabulaires', TaraText.small, c.textTertiary),
                ),
              ),
            ],
          ),
          AmountText(12500, style: TaraText.amountXL),
          const SizedBox(height: 4),
          AmountText(3000, style: TaraText.amountL),
          const SizedBox(height: 12),
          sample('Titre d’accueil · 30', TaraText.titleAccess),
          sample('Titre de formulaire · 26', TaraText.titleForm),
          sample('Titre de course · 22', TaraText.titleCourse),
          sample('Titre de panneau · 19', TaraText.titlePanel),
          sample('Titre de carte · 17', TaraText.cardTitle),
          const SizedBox(height: 6),
          sample('Texte courant · 15 · Plus Jakarta Sans', TaraText.body, c.textSecondary),
          sample('Libellé · 13', TaraText.label, c.textSecondary),
          sample('Aide et métadonnées · 12', TaraText.small, c.textTertiary),
          const SizedBox(height: 6),
          sample('SURTITRE · 11', TaraText.overline, c.accentText),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(label: 'Accepter la course', icon: TaraIcons.check, onPressed: () {}),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Encaisser 12 500 FCFA', strong: true, onPressed: () {}),
        const SizedBox(height: 12),
        const PrimaryButton(label: 'Bouton désactivé', onPressed: null),
        const SizedBox(height: 12),
        GlassButton(label: 'Refuser', onPressed: () {}),
        const SizedBox(height: 12),
        Row(
          children: [
            GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: () {}),
            const SizedBox(width: 10),
            GlassIconButton(icon: TaraIcons.navigation, label: l.recenterMap, onPressed: () {}),
            const SizedBox(width: 10),
            GlassIconButton(icon: TaraIcons.headset, label: 'Support', onPressed: () {}, badge: true),
            const Spacer(),
            CallButton(label: l.callPerson('Aïcha'), onPressed: () {}),
            const SizedBox(width: 10),
            SosButton(label: l.safetyAlert, onPressed: () {}),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          child: TaraLink(label: 'Renvoyer le code', onPressed: () {}),
        ),
      ],
    );
  }

  Widget _inputs(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TaraTextField(
          label: 'Numéro de téléphone',
          hint: '6XX XX XX XX',
          keyboardType: TextInputType.phone,
          leading: PhonePrefixButton(prefix: '+237', semanticLabel: 'Indicatif du Cameroun'),
        ),
        const SizedBox(height: 16),
        CodeCells(length: 6, autofocus: false, digitLabel: (i) => l.digitLabel(i)),
        const SizedBox(height: 16),
        ChoiceChips<_Pay>(
          options: [
            ChoiceOption(_Pay.cash, l.cash, icon: TaraIcons.cash),
            ChoiceOption(_Pay.mobileMoney, l.mobileMoney, icon: TaraIcons.phone),
          ],
          selected: _pay,
          onSelected: (value) => setState(() => _pay = value),
        ),
        const SizedBox(height: 16),
        const InfoNote(text: 'Vos documents restent privés et servent uniquement à vérifier votre identité.'),
      ],
    );
  }

  Widget _progress(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LiquidProgressBar(value: .4, semanticLabel: 'Étape 2 sur 5'),
        const SizedBox(height: 22),
        CourseStepper(labels: [l.stepPickup, l.stepCollect, l.stepDelivery], activeIndex: 1),
        const SizedBox(height: 22),
        LiquidSegmented<_Period>(
          segments: [(_Period.day, l.periodDay), (_Period.week, l.periodWeek), (_Period.month, l.periodMonth)],
          selected: _period,
          onChanged: (value) => setState(() => _period = value),
        ),
      ],
    );
  }

  Widget _status(BuildContext context, AppLocalizations l) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OnlineToggle(label: l.online, semanticLabel: l.goOfflineLabel, onToggle: () {}),
        ),
        const SizedBox(height: 24),
        PowerButton(label: l.goOnline, semanticLabel: l.goOnlineLabel, onPressed: () {}),
        const SizedBox(height: 28),
        _CountdownDemo(unitLabel: l.seconds, semanticLabel: l.secondsRemaining),
        const SizedBox(height: 28),
        SosHoldButton(
          sent: _sosSent,
          onSent: () => setState(() => _sosSent = true),
          idleHint: l.sosHold,
          holdingHint: l.sosHoldRemaining,
          sentHint: l.sosSent,
          semanticLabel: l.sosHoldLabel,
        ),
        if (_sosSent) TaraLink(label: 'Réinitialiser', onPressed: () => setState(() => _sosSent = false)),
      ],
    );
  }

  Widget _cards(BuildContext context, AppLocalizations l) {
    final c = TaraColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListRow(
                leading: const InitialsAvatar(name: 'Aïcha Ngono'),
                title: 'Aïcha Ngono',
                subtitle: 'Bonamoussadi · ${formatDistance(2400)}',
                trailing: AmountText(1500, style: TaraText.cardTitle),
                onTap: () {},
              ),
              const ListRow(
                leading: IconTile(icon: TaraIcons.package),
                title: 'Colis moyen',
                subtitle: 'Enlèvement à Akwa',
                trailing: IconTile(icon: TaraIcons.check, tone: TintTone.success, size: 32, radius: 10),
              ),
              const ListRow(
                leading: IconTile(icon: TaraIcons.alertCircle, tone: TintTone.danger),
                title: 'Livraison échouée',
                subtitle: 'Destinataire absent',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoPill(label: l.online, dot: c.online, blinkDot: true),
            InfoPill(label: formatMinutes(const Duration(minutes: 12)), icon: TaraIcons.clock),
            InfoPill(label: formatDistance(2400), icon: TaraIcons.mapPin, tone: TintTone.accent),
            const InfoPill(label: 'Payé', icon: TaraIcons.check, tone: TintTone.success),
          ],
        ),
        const SizedBox(height: 12),
        TintBox(
          child: Row(
            children: [
              Expanded(
                child: Text('À encaisser à l’enlèvement', style: TaraText.text.copyWith(color: c.textPrimary)),
              ),
              AmountText(12500, style: TaraText.cardTitle),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TintBox(
          tone: TintTone.success,
          child: Text('Paiement reçu', style: TaraText.text.copyWith(color: c.success)),
        ),
        const SizedBox(height: 10),
        TintBox(
          tone: TintTone.danger,
          child: Text('Le paiement a échoué', style: TaraText.text.copyWith(color: c.dangerText)),
        ),
        const SizedBox(height: 12),
        OfflineBanner(title: l.offlineBannerTitle, detail: l.offlineBannerPending(3)),
      ],
    );
  }

  Widget _map(BuildContext context) {
    final c = TaraColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 180,
        color: c.mapGround,
        child: Stack(
          children: [
            Positioned(left: 0, right: 0, top: 70, height: 14, child: ColoredBox(color: c.mapMajorRoad)),
            Positioned(left: 120, width: 10, top: 0, bottom: 0, child: ColoredBox(color: c.mapMinorRoad)),
            Positioned(right: 30, top: 18, width: 70, height: 40, child: ColoredBox(color: c.mapWater)),
            Positioned(left: 20, top: 110, width: 80, height: 50, child: ColoredBox(color: c.mapBlocks)),
            const Align(alignment: Alignment(-0.6, -0.05), child: RiderPin(heading: 0.6)),
            const Align(alignment: Alignment(0.15, -0.3), child: PickupPin()),
            const Align(alignment: Alignment(0.75, 0.55), child: DestinationPin()),
          ],
        ),
      ),
    );
  }

  Widget _animations(BuildContext context, AppLocalizations l) {
    final c = TaraColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Column(
            children: [
              GooLoader(semanticLabel: l.searchingJobs),
              const SizedBox(height: 12),
              Text(l.searchingJobs, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(
                l.searchingJobsHint,
                textAlign: TextAlign.center,
                style: TaraText.label.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: 'Ondes',
                child: PulseRings(
                  size: 44,
                  color: TaraBrand.orange,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(gradient: TaraBrand.gradient, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'Liquide',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: LiquidFill(
                      level: .55,
                      front: TaraBrand.verticalGradient,
                      back: TaraBrand.amber.withValues(alpha: .35),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'Rotation',
                child: Spin(
                  period: const Duration(milliseconds: 1400),
                  child: TaraIcon(TaraIcons.refresh, size: 30, color: c.accentText),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const SizedBox(
            height: 6,
            child: FlowingGradient(
              colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.orange, TaraBrand.amber],
              period: Duration(seconds: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navigation(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Panneau du bas',
                action: TaraLink(label: 'Détails', onPressed: () {}),
              ),
              const SizedBox(height: 12),
              CourseStepper(labels: [l.stepPickup, l.stepCollect, l.stepDelivery], activeIndex: 2),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FloatingTabBar(
          items: [
            TabItem(TaraIcons.home, l.tabHome),
            TabItem(TaraIcons.activity, l.tabActivity),
            TabItem(TaraIcons.user, l.tabProfile),
          ],
          current: _tab,
          onSelected: (index) => setState(() => _tab = index),
        ),
      ],
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Text(text.toUpperCase(), style: TaraText.overline.copyWith(color: c.accentText));
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.chipBorder),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaraText.small.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          SizedBox(height: 72, child: Center(child: child)),
          const SizedBox(height: 6),
          Text(label, style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}

/// Compte à rebours de démonstration : 30 s en boucle (A3).
class _CountdownDemo extends StatefulWidget {
  const _CountdownDemo({required this.unitLabel, required this.semanticLabel});

  final String unitLabel;
  final String Function(int seconds) semanticLabel;

  @override
  State<_CountdownDemo> createState() => _CountdownDemoState();
}

class _CountdownDemoState extends State<_CountdownDemo> with SingleTickerProviderStateMixin {
  static const _total = 30;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _total),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final remaining = _total - (_controller.value * _total).floor();
        return CountdownRing(
          remaining: remaining,
          total: _total,
          unitLabel: widget.unitLabel,
          semanticLabel: widget.semanticLabel(remaining),
        );
      },
    );
  }
}
