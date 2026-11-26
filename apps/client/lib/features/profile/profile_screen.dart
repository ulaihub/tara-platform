import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/app_settings.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/components/terms_flow.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../common/scoped_page.dart';
import '../home/home_screen.dart' show walletProvider;
import '../legal/terms_screen.dart';
import '../onboarding/intro_screen.dart';
import '../order/address_editor.dart';
import '../order/pickup_step.dart' show pickupAddressesProvider;
import '../support/support.dart';
import 'delete_account_screen.dart';

/// Chiffres du profil (livraisons, réussite, arrivée) ; rien à montrer si la lecture échoue.
final meStatsProvider = FutureProvider.autoDispose<MeStats>((ref) => ref.read(clientApiProvider).meStats());

/// Onglet Profil de l'expéditeur (non dessiné : style Tara) : identité et boutique, code de
/// parrainage à partager (C6), affichage (thème, langue, animations), support, déconnexion.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.7), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  bool _confirmLogout = false;
  bool _loggingOut = false;
  void _setLanguage(AppSettings settings, String? code) {
    settings.locale = code == null ? null : Locale(code);
    // Les SMS et notifications suivent la langue choisie ; sans réseau, à la prochaine fois.
    final language = settings.languageCode(WidgetsBinding.instance.platformDispatcher.locale);
    unawaited(ref.read(clientApiProvider).updateLocale(language).catchError((Object _) {}));
  }

  Future<void> _logout() async {
    if (!_confirmLogout) {
      setState(() => _confirmLogout = true);
      return;
    }
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
  }

  /// Page d'une ligne du menu : retour, titre, puis le bloc de réglages existant.
  void _open(String title, Widget Function(BuildContext context) body) => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (route) => _ProfilePage(
          title: title,
          onBack: () => Navigator.of(route).pop(),
          child: Builder(builder: body),
        ),
      ),
    ),
  );

  @override
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final settings = AppSettingsScope.of(context);
    final me = widget.me;
    final support = ref.watch(appConfigProvider).value?.supportPhone;
    final version = ref.watch(appVersionProvider).value;
    final addresses = ref.watch(pickupAddressesProvider).value;
    final plan = ref.watch(walletProvider).value?.plan;
    final themeName = switch (settings.themeMode) {
      ThemeMode.light => l.themeLight,
      ThemeMode.dark => l.themeDark,
      ThemeMode.system => l.optionAuto,
    };
    final language = switch (settings.locale?.languageCode) {
      'fr' => 'Français',
      'en' => 'English',
      _ => l.optionAuto,
    };
    final rows = <_MenuRow>[
      _MenuRow(TaraIcons.mapPin, l.myAddresses, addresses == null ? '' : '${addresses.length}', () {
        _open(l.myAddresses, (_) => const _AddressesCard());
      }),
      _MenuRow(TaraIcons.shield, l.securitySection, l.profileSecurityValue, () {
        _open(l.securitySection, (_) => const SecurityCard());
      }),
      _MenuRow(TaraIcons.sun, l.profileDisplayRow, themeName, () {
        _open(
          l.profileDisplayRow,
          (context) => _DisplayCard(settings: settings, onLanguage: (code) => _setLanguage(settings, code)),
        );
      }),
      _MenuRow(TaraIcons.globe, l.languageLabel, language, () {
        _open(
          l.profileDisplayRow,
          (context) => _DisplayCard(settings: settings, onLanguage: (code) => _setLanguage(settings, code)),
        );
      }),
      _MenuRow(TaraIcons.headset, l.profileSupportRow, '', () {
        _open(l.helpSection, (context) => _HelpCard(support: support));
      }),
      _MenuRow(TaraIcons.play, l.profileReplayIntro, '', () {
        unawaited(
          Navigator.of(context)
              .push(scopedPage<void>(context, (route) => ClientIntroScreen(onDone: () => Navigator.of(route).pop()))),
        );
      }),
      _MenuRow(TaraIcons.document, l.profileTermsRow, '', () {
        _open(l.profileTermsRow, (context) => _DataCard(me: me));
      }),
      _MenuRow(TaraIcons.logout, l.logout, '', () => setState(() => _confirmLogout = true), danger: true),
    ];
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + TaraTabShell.bottomInset(context)),
        children: [
          // En-tête de la maquette : avatar dans un anneau qui tourne, nom, numéro, pastilles.
          Center(child: _RingAvatar(name: me.fullName ?? '')),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              me.fullName ?? '',
              textAlign: TextAlign.center,
              style: TaraText.titleCourse.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayPhone(me.phone),
            textAlign: TextAlign.center,
            style: TaraText.label.copyWith(color: c.textSecondary),
          ),
          if (me.merchant case final shop?) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(label: shop.shopName),
                if (plan != null && plan != 'FREE') _Chip(label: l.profilePlanChip, brand: true),
              ],
            ),
          ],
          if (ref.watch(meStatsProvider).value case final stats?) ...[
            const SizedBox(height: 16),
            _StatsCard(stats: stats),
          ],
          if (me.referralCode case final code?) ...[
            const SizedBox(height: 16),
            _ReferralTicket(
              code: code,
              shop: me.merchant != null,
              onShare: () => unawaited(ref.read(shareProvider)(l.profileReferralShare(code), null)),
            ),
          ],
          const SizedBox(height: 14),
          GlassCard(
            radius: 22,
            shadow: false,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.glassBorder),
                  _MenuTile(row: rows[i]),
                ],
              ],
            ),
          ),
          if (_confirmLogout || _loggingOut) ...[
            const SizedBox(height: 14),
            _LogoutBlock(
              confirming: _confirmLogout,
              busy: _loggingOut,
              onLogout: _logout,
              onCancel: () => setState(() => _confirmLogout = false),
            ),
          ],
          if (version != null) ...[
            const SizedBox(height: 18),
            Center(
              child: Text(l.appVersion(version), style: TaraText.small.copyWith(color: c.textTertiary)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Trois chiffres (maquette) : livraisons réussies, part réussie, mois d'arrivée sur Tara.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final MeStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final rate = stats.successRate == null ? '—' : '${stats.successRate}\u00a0%';
    final since = DateFormat('MMMM y', Localizations.localeOf(context).toLanguageTag()).format(stats.memberSince);
    Widget cell(String value, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 20)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .66), fontSize: 11),
          ),
        ],
      ),
    );
    Widget divider() => Container(width: 1, height: 34, color: c.glassBorder);
    return Semantics(
      label: l.profileStatsLabel(stats.delivered, rate, since),
      excludeSemantics: true,
      child: GlassCard(
        radius: 22,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            cell(formatAmount(stats.delivered), l.profileStatDelivered),
            divider(),
            cell(rate, l.profileStatSuccess),
            divider(),
            cell(since, l.profileStatSince),
          ],
        ),
      ),
    );
  }
}

@immutable
class _MenuRow {
  const _MenuRow(this.icon, this.label, this.value, this.onTap, {this.danger = false});
  final TaraIconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool danger;
}

/// Ligne du menu (maquette) : icône, libellé, valeur discrète, chevron ; en rouge pour
/// la déconnexion.
class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.row});
  final _MenuRow row;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final ink = row.danger ? c.dangerText : c.textPrimary;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: row.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  TaraIcon(row.icon, size: 22, strokeWidth: 1.8, color: ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      row.label,
                      style: TaraText.text.copyWith(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (row.value.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        row.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaraText.label.copyWith(color: c.textTertiary),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  TaraIcon(TaraIcons.chevronRight, size: 16, color: c.textPrimary.withValues(alpha: .40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar de la maquette : initiales sur le dégradé, dans un anneau dégradé qui tourne.
class _RingAvatar extends StatelessWidget {
  const _RingAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return ExcludeSemantics(
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          children: [
            Positioned.fill(
              child: MotionBuilder(
                period: const Duration(seconds: 6),
                builder: (context, t, child) => Transform.rotate(angle: t * 2 * math.pi, child: child),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, Color(0x00FF3D00), TaraBrand.amber],
                      stops: [0, .25, .45, .7, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: DecoratedBox(
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: TaraBrand.gradient),
                  child: Center(
                    child: Text(
                      initials,
                      style: TaraText.titleCourse.copyWith(
                        color: TaraBrand.onBrand,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.brand = false});
  final String label;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: brand ? null : c.glassFallback,
        gradient: brand ? TaraBrand.gradient : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TaraText.smallStrong.copyWith(
          color: brand ? TaraBrand.onBrand : c.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Bon de parrainage (maquette) : ticket clair à deux parties, séparées par un pointillé et
/// deux encoches ; le code et « Partager » à droite.
class _ReferralTicket extends StatelessWidget {
  const _ReferralTicket({required this.code, required this.shop, required this.onShare});
  final String code;
  final bool shop;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    const ink = Color(0xFF16120E);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(140, 70, 10, .10), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-.35, -1),
              end: Alignment(.35, 1),
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF1E2)],
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          shop ? l.profileReferShop : l.referralTitle,
                          style: TaraText.text.copyWith(color: ink, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.profileReferBody,
                          style: TaraText.small.copyWith(color: const Color.fromRGBO(22, 18, 14, .70), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: CustomPaint(
                    painter: _TicketEdge(notch: c.bg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(
                          code,
                          style: TaraText.text.copyWith(
                            fontFamily: TaraText.sora,
                            color: const Color(0xFF9A3412),
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          button: true,
                          label: l.profileShare,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: onShare,
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TaraIcon(TaraIcons.send, size: 14, strokeWidth: 2.2, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(l.profileShare, style: TaraText.smallStrong.copyWith(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

/// Pointillé vertical et encoches du ticket, de la couleur du fond de l'écran.
class _TicketEdge extends CustomPainter {
  _TicketEdge({required this.notch});
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = const Color.fromRGBO(194, 65, 12, .30)
      ..strokeWidth = 2;
    for (double y = 12; y < size.height - 12; y += 8) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 4), dash);
    }
    final hole = Paint()..color = notch;
    canvas
      ..drawCircle(const Offset(1, -1), 10, hole)
      ..drawCircle(Offset(1, size.height + 1), 10, hole);
  }

  @override
  bool shouldRepaint(_TicketEdge old) => old.notch != notch;
}

/// Page ouverte depuis une ligne du menu : retour, titre, contenu qui défile.
class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.title, required this.onBack, required this.child});
  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return TaraScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: onBack),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Service client : demande liée à une commande, ou appel au numéro de Tara.
class _HelpCard extends ConsumerWidget {
  const _HelpCard({required this.support});
  final String? support;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final phone = support;
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          ListRow(
            leading: const IconTile(icon: TaraIcons.message),
            title: l.supportMenuRow,
            subtitle: l.supportMenuRowSubtitle,
            trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
            onTap: () => unawaited(openSupport(context, ref)),
          ),
          if (phone != null)
            ListRow(
              leading: const IconTile(icon: TaraIcons.headset),
              title: l.supportTara,
              subtitle: displayPhone(phone),
              trailing: TaraIcon(TaraIcons.phone, size: 20, color: c.accentText),
              onTap: () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
            ),
        ],
      ),
    );
  }
}

/// Conditions et mes données : textes acceptés, copie de mes données, suppression du compte.
class _DataCard extends ConsumerStatefulWidget {
  const _DataCard({required this.me});
  final Me me;

  @override
  ConsumerState<_DataCard> createState() => _DataCardState();
}

class _DataCardState extends ConsumerState<_DataCard> {
  bool _exporting = false;
  String? _exportError;

  Future<void> _exportData() async {
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      await exportMyData(ref, AppLocalizations.of(context).exportDataShare);
    } catch (error) {
      if (mounted) setState(() => _exportError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TermsCard(),
        const SizedBox(height: 20),
        SectionHeader(title: l.accountDataSection),
        const SizedBox(height: 8),
        GlassCard(
          radius: 22,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              ListRow(
                leading: const IconTile(icon: TaraIcons.download),
                title: l.exportDataRow,
                subtitle: l.exportDataRowSubtitle,
                trailing: _exporting
                    ? const SizedBox(width: 44, child: GooLoader(compact: true))
                    : TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
                onTap: _exporting ? null : () => unawaited(_exportData()),
              ),
              ListRow(
                leading: const IconTile(icon: TaraIcons.close),
                title: l.deleteAccountRow,
                subtitle: l.deleteAccountRowSubtitle,
                trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
                onTap: () => unawaited(
                  Navigator.of(context).push(
                    scopedPage<void>(
                      context,
                      (route) => DeleteAccountScreen(me: widget.me, onBack: () => Navigator.of(route).pop()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_exportError case final error?) ...[const SizedBox(height: 8), ErrorLine(error)],
      ],
    );
  }
}

class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.settings, required this.onLanguage});
  final AppSettings settings;
  final ValueChanged<String?> onLanguage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final effects = settings.effects;
    Widget setting(String label, Widget control, {String? hint}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        control,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint, style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ],
    );
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: ListenableBuilder(
        listenable: Listenable.merge([effects, settings]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            setting(
              l.themeLabel,
              LiquidSegmented<ThemeMode>(
                compact: true,
                segments: [
                  (ThemeMode.system, l.optionAuto),
                  (ThemeMode.light, l.themeLight),
                  (ThemeMode.dark, l.themeDark),
                ],
                selected: settings.themeMode,
                onChanged: (mode) => settings.themeMode = mode,
              ),
            ),
            const SizedBox(height: 16),
            setting(
              l.languageLabel,
              LiquidSegmented<String>(
                compact: true,
                segments: [('auto', l.optionAuto), ('fr', 'Français'), ('en', 'English')],
                selected: settings.locale?.languageCode ?? 'auto',
                onChanged: (code) => onLanguage(code == 'auto' ? null : code),
              ),
            ),
            const SizedBox(height: 16),
            setting(
              l.effectsLabel,
              LiquidSegmented<EffectsPreference>(
                compact: true,
                segments: [
                  (EffectsPreference.automatic, l.optionAuto),
                  (EffectsPreference.full, l.effectsFull),
                  (EffectsPreference.reduced, l.effectsReduced),
                ],
                selected: effects.preference,
                onChanged: (value) => effects.preference = value,
              ),
              hint: effects.preference == EffectsPreference.automatic && effects.lowEndDevice
                  ? l.effectsAutoReduced
                  : l.effectsHint,
            ),
            const SizedBox(height: 16),
            setting(
              l.glassLabel,
              LiquidSegmented<GlassLevel>(
                compact: true,
                segments: [
                  (GlassLevel.clear, l.glassClear),
                  (GlassLevel.balanced, l.glassBalanced),
                  (GlassLevel.opaque, l.glassOpaque),
                ],
                selected: effects.glassLevel,
                onChanged: (value) => effects.glassLevel = value,
              ),
              hint: l.glassHint,
            ),
            const SizedBox(height: 16),
            MergeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleSounds(context, settings),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.soundsLabel,
                            style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(l.soundsHint, style: TaraText.small.copyWith(color: c.textTertiary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassSwitch(value: settings.sounds, onChanged: (_) => _toggleSounds(context, settings)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Déconnexion confirmée.
class _LogoutBlock extends StatelessWidget {
  const _LogoutBlock({required this.confirming, required this.busy, required this.onLogout, required this.onCancel});
  final bool confirming;
  final bool busy;
  final VoidCallback onLogout;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    if (!confirming) {
      return GlassButton(label: l.logout, icon: TaraIcons.power, color: c.dangerText, onPressed: onLogout);
    }
    return TintBox(
      tone: TintTone.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(l.logoutConfirm, style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(label: l.cancel, onPressed: busy ? null : onCancel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: busy
                    ? const SizedBox(height: 48, child: Center(child: GooLoader(compact: true)))
                    : GlassButton(label: l.logout, color: c.dangerText, onPressed: onLogout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sons activés : un exemple se fait entendre aussitôt.
void _toggleSounds(BuildContext context, AppSettings settings) {
  settings.sounds = !settings.sounds;
  if (settings.sounds) TaraFeedback.play(context, TaraSound.received);
}

/// Conditions et confidentialité : version acceptée et date (copie consultable), nouvelle
/// version à accepter.
class _TermsCard extends ConsumerWidget {
  const _TermsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final status = ref.watch(termsStatusProvider).value;
    void open(Widget Function(BuildContext context) builder) =>
        unawaited(Navigator.of(context).push(scopedPage<void>(context, builder)));
    Widget row(String document, String title) {
      final accepted = status?.accepted.where((item) => item.document == document).firstOrNull;
      return ListRow(
        leading: const IconTile(icon: TaraIcons.shieldCheck),
        title: title,
        subtitle: accepted == null
            ? null
            : l.termsAcceptedOn(accepted.version, formatLegalDay(context, accepted.acceptedAt)),
        trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
        onTap: () => open((_) => LegalTextScreen(document: document, acceptedAt: accepted?.acceptedAt)),
      );
    }

    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          if (status != null && !status.upToDate)
            ListRow(
              leading: const IconTile(icon: TaraIcons.alertCircle),
              title: l.termsToSign,
              trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.accentText),
              onTap: () => open((route) => TermsScreen.update(onSigned: () => Navigator.of(route).pop())),
            ),
          row('expediteurs', l.termsTitle),
          row(LegalApi.privacyDocument, l.termsPrivacyTitle),
        ],
      ),
    );
  }
}

class _AddressesCard extends ConsumerStatefulWidget {
  const _AddressesCard();

  @override
  ConsumerState<_AddressesCard> createState() => _AddressesCardState();
}

class _AddressesCardState extends ConsumerState<_AddressesCard> {
  String? _confirming;
  bool _removing = false;
  String? _error;

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final added = await navigator.push<Address>(
      scopedPage(
        context,
        (context) =>
            AddressEditor(title: l.newAddressTitle, forPickup: true, onBack: navigator.pop, onSaved: navigator.pop),
      ),
    );
    if (added != null && mounted) ref.invalidate(pickupAddressesProvider);
  }

  Future<void> _remove(Address address) async {
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      await ref.read(clientApiProvider).deleteAddress(address.id);
      ref.invalidate(pickupAddressesProvider);
      if (mounted) setState(() => _confirming = null);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final addresses = ref.watch(pickupAddressesProvider).value ?? const <Address>[];
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l.myAddressesEmpty, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
            ),
          for (final (index, address) in addresses.indexed) ...[
            if (index > 0) Divider(height: 1, color: c.glassBorder),
            if (_confirming == address.id)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.removeAddressConfirm(address.label ?? ''),
                      style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4),
                    ),
                    if (_error != null) ...[const SizedBox(height: 6), ErrorLine(_error!)],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: l.cancel,
                            height: 44,
                            onPressed: _removing ? null : () => setState(() => _confirming = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassButton(
                            label: l.removeYes,
                            height: 44,
                            color: c.dangerText,
                            onPressed: _removing ? null : () => unawaited(_remove(address)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ListRow(
                      leading: const IconTile(icon: TaraIcons.mapPin),
                      title: address.label ?? '',
                      subtitle: [?address.neighborhood?.name, address.landmark].join(' · '),
                    ),
                  ),
                  GlassIconButton(
                    icon: TaraIcons.close,
                    label: l.removeAddress(address.label ?? ''),
                    size: 40,
                    onPressed: () => setState(() {
                      _confirming = address.id;
                      _error = null;
                    }),
                  ),
                ],
              ),
          ],
          Center(
            child: TaraLink(label: l.addAddress, onPressed: () => unawaited(_add())),
          ),
        ],
      ),
    );
  }
}

/// Copie de toutes ses données (droit d'accès), en fichier JSON partagé ou enregistré
/// depuis la feuille de partage du téléphone.
Future<void> exportMyData(WidgetRef ref, String shareText) async {
  final data = await ref.read(clientApiProvider).exportData();
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  final date = DateTime.now().toIso8601String().substring(0, 10);
  await ref.read(shareFileProvider)(bytes, 'tara-donnees-$date.json', 'application/json', shareText);
}
