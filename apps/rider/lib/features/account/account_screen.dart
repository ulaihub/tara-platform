import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';
import 'package:tara_ui/vehicle_labels.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../common/scoped_page.dart';
import '../home/home_widgets.dart';
import '../legal/terms_screen.dart';
import '../onboarding/documents_controller.dart';
import '../onboarding/documents_screen.dart';
import '../support/support.dart';
import 'close_account_screen.dart';
import 'emergency_contact_screen.dart';
import 'vehicle_screen.dart';

enum _Sub { documents, contact, vehicle, close, terms, security, display }

/// Profil et réglages (onglet Profil, non dessiné dans la maquette : passation §7) :
/// identité et véhicule, pièces et leur état (une pièce refusée ou expirée se renvoie
/// d'ici), contact d'urgence, affichage (thème, langue, effets), support, déconnexion.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.pickPhoto = pickWithCamera});

  /// Photo d'une pièce à renvoyer (remplacée dans les tests).
  final PickPhoto pickPhoto;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  // Formes liquides de la maquette (mêmes que l'accueil hors ligne).
  static const _blobs = [
    BlobSpec(alignment: Alignment(-.69, -.55), size: 300, colors: BlobSpec.warm, blur: 46, opacity: .76),
    BlobSpec(
      alignment: Alignment(.74, .02),
      size: 260,
      colors: BlobSpec.soft,
      blur: 46,
      opacity: .44,
      delay: Duration(seconds: 4),
    ),
    BlobSpec(
      alignment: Alignment(-.59, .71),
      size: 240,
      colors: BlobSpec.warm,
      blur: 46,
      opacity: .44,
      delay: Duration(seconds: 9),
    ),
  ];

  late Future<Json> _me = ref.read(riderApiProvider).me();
  _Sub? _sub;
  bool _confirmLogout = false;
  bool _loggingOut = false;
  bool _exporting = false;
  String? _exportError;

  void _reload() {
    setState(() => _me = ref.read(riderApiProvider).me());
    ref.invalidate(documentsControllerProvider);
  }

  void _setLanguage(AppSettings settings, String? code) {
    settings.locale = code == null ? null : Locale(code);
    // Les SMS et notifications suivent la langue choisie ; sans réseau, à la prochaine fois.
    final language = settings.languageCode(WidgetsBinding.instance.platformDispatcher.locale);
    unawaited(ref.read(riderApiProvider).updateLocale(language).catchError((Object _) {}));
  }

  Future<void> _logout() async {
    if (!_confirmLogout) {
      setState(() => _confirmLogout = true);
      return;
    }
    setState(() => _loggingOut = true);
    final online = ref.read(onlineControllerProvider);
    if (online.online) {
      try {
        await online.goOffline();
      } catch (_) {
        // Sans réseau : le serveur le passera hors ligne faute de position.
      }
    }
    await ref.read(authControllerProvider.notifier).logout();
  }

  /// Copie de toutes ses données (droit d'accès), en fichier JSON partagé ou enregistré
  /// depuis la feuille de partage du téléphone.
  Future<void> _exportData() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final data = await ref.read(riderApiProvider).exportData();
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final date = DateTime.now().toIso8601String().substring(0, 10);
      await ref.read(shareFileProvider)(bytes, 'tara-donnees-$date.json', 'application/json', l.exportDataShare);
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
    final settings = AppSettingsScope.of(context);
    final documents = ref.watch(documentsControllerProvider);
    final profile = documents.value?.profile;
    final config = ref.watch(riderConfigProvider).value;
    final version = ref.watch(appVersionProvider).value;
    final activeOrder = ref.watch(activeOrderProvider);
    final queue = ref.watch(actionQueueProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: TaraScreen(
            blobs: _blobs,
            safeBottom: false,
            // Le contenu défile jusqu'en bas de l'écran, sous la barre d'onglets en verre.
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 24 + TaraTabShell.bottomInset(context)),
                children: [
                  FutureBuilder<Json>(
                    future: _me,
                    builder: (context, snapshot) =>
                        _ProfileHeader(name: snapshot.data?['fullName'] as String?, profile: profile),
                  ),
                  const SizedBox(height: 14),
                  _DisplayCard(settings: settings, onLanguage: (code) => _setLanguage(settings, code)),
                  if (documents.hasError) ...[const SizedBox(height: 14), _Failed(onRetry: _reload)],
                  // Pièce refusée, expirée ou manquante : l'alerte reste en évidence.
                  if (documents.value case final data? when data.needsAttention) ...[
                    const SizedBox(height: 14),
                    _DocumentsSummary(state: data, onOpen: () => setState(() => _sub = _Sub.documents)),
                  ],
                  const SizedBox(height: 10),
                  _MenuLine(
                    icon: TaraIcons.idCard,
                    title: l.myDocuments,
                    subtitle: l.myDocumentsRowSubtitle,
                    onTap: documents.value == null ? null : () => setState(() => _sub = _Sub.documents),
                  ),
                  _MenuLine(
                    icon: TaraIcons.moto,
                    title: l.vehicleTitle,
                    subtitle: switch ((profile?.vehicleBrand, profile?.vehicleColor)) {
                      (final brand?, final color?) =>
                        '${vehicleBrandName(brand, Localizations.localeOf(context))} · '
                            '${vehicleColorName(color, Localizations.localeOf(context))}'
                            '${profile?.plateNumber == null ? '' : ' · ${profile!.plateNumber}'}',
                      _ => l.vehicleRowEmpty,
                    },
                    onTap: profile == null ? null : () => setState(() => _sub = _Sub.vehicle),
                  ),
                  _MenuLine(
                    icon: TaraIcons.contacts,
                    title: l.emergencyContactTitle,
                    subtitle: switch ((profile?.emergencyContactName, profile?.emergencyContactPhone)) {
                      (final name?, final phone?) => '$name · ${maskedPhone(phone)}',
                      _ => l.emergencyHelp,
                    },
                    onTap: profile == null ? null : () => setState(() => _sub = _Sub.contact),
                  ),
                  _TermsLine(onTap: () => setState(() => _sub = _Sub.terms)),
                  _MenuLine(
                    icon: TaraIcons.message,
                    title: l.supportMenuRow,
                    subtitle: l.supportMenuRowSubtitle,
                    onTap: () => unawaited(openSupport(context, ref)),
                  ),
                  if (config?.supportPhone case final support?)
                    _MenuLine(
                      icon: TaraIcons.headset,
                      title: l.supportTara,
                      subtitle: displayPhone(support),
                      trailing: TaraIcon(TaraIcons.phone, size: 20, color: c.accentText),
                      onTap: () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: support))),
                    ),
                  _MenuLine(
                    icon: TaraIcons.lock,
                    title: l.securityRow,
                    subtitle: l.securityRowSubtitle,
                    onTap: () => setState(() => _sub = _Sub.security),
                  ),
                  _MenuLine(
                    icon: TaraIcons.globe,
                    title: l.displayMoreRow,
                    subtitle: settings.locale == null
                        ? l.optionAuto
                        : settings.locale!.languageCode == 'en'
                        ? 'English'
                        : 'Français',
                    onTap: () => setState(() => _sub = _Sub.display),
                  ),
                  _MenuLine(
                    icon: TaraIcons.download,
                    title: l.exportDataRow,
                    subtitle: l.exportDataRowSubtitle,
                    trailing: _exporting ? const SizedBox(width: 44, child: GooLoader(compact: true)) : null,
                    onTap: _exporting ? null : () => unawaited(_exportData()),
                  ),
                  _MenuLine(
                    icon: TaraIcons.closeCircle,
                    title: l.closeAccountRow,
                    subtitle: l.closeAccountRowSubtitle,
                    danger: true,
                    onTap: () => setState(() => _sub = _Sub.close),
                  ),
                  if (_exportError case final error?) ...[const SizedBox(height: 8), ErrorLine(error)],
                  const SizedBox(height: 24),
                  ListenableBuilder(
                    listenable: Listenable.merge([activeOrder, queue]),
                    builder: (context, _) => _LogoutBlock(
                      blocked: activeOrder.order != null
                          ? l.logoutBlockedCourse
                          : queue.pendingCount > 0
                          ? l.logoutBlockedPending
                          : null,
                      confirming: _confirmLogout,
                      busy: _loggingOut,
                      onLogout: _logout,
                      onCancel: () => setState(() => _confirmLogout = false),
                    ),
                  ),
                  if (version != null) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Text(l.appVersion(version), style: TaraText.small.copyWith(color: c.textTertiary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_sub == _Sub.documents)
          Positioned.fill(
            child: HideTabBar(
              child: DocumentsScreen(
                fromProfile: true,
                pickPhoto: widget.pickPhoto,
                onDone: () => setState(() => _sub = null),
              ),
            ),
          ),
        if (_sub case _Sub.terms || _Sub.security || _Sub.display)
          Positioned.fill(
            child: HideTabBar(
              child: _SubPage(
                title: switch (_sub) {
                  _Sub.terms => l.termsSection,
                  _Sub.security => l.securityRow,
                  _ => l.displayMoreRow,
                },
                onBack: () => setState(() => _sub = null),
                child: switch (_sub) {
                  _Sub.terms => const _TermsCard(),
                  _Sub.security => const SecurityCard(),
                  _ => _DisplayCard(
                    settings: settings,
                    onLanguage: (code) => _setLanguage(settings, code),
                    languageAndSounds: true,
                  ),
                },
              ),
            ),
          ),
        if (_sub == _Sub.close)
          Positioned.fill(
            child: HideTabBar(child: CloseAccountScreen(onBack: () => setState(() => _sub = null))),
          ),
        if (_sub == _Sub.vehicle && profile != null)
          Positioned.fill(
            child: HideTabBar(
              child: VehicleScreen(
                profile: profile,
                onBack: () => setState(() => _sub = null),
                onSaved: (updated) {
                  ref.read(documentsControllerProvider.notifier).replaceProfile(updated);
                  setState(() => _sub = null);
                },
              ),
            ),
          ),
        if (_sub == _Sub.contact && profile != null)
          Positioned.fill(
            child: HideTabBar(
              child: EmergencyContactScreen(
                profile: profile,
                onBack: () => setState(() => _sub = null),
                onSaved: (updated) {
                  ref.read(documentsControllerProvider.notifier).replaceProfile(updated);
                  setState(() => _sub = null);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Pièces : à renvoyer (refusée, expirée ou manquante), en vérification, ou toutes validées.
class _DocumentsSummary extends StatelessWidget {
  const _DocumentsSummary({required this.state, required this.onOpen});
  final DocumentsState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final items = state.items;
    final toFix = [
      for (final item in items)
        if (item.status == DocumentStatus.rejected ||
            item.status == DocumentStatus.expired ||
            item.status == DocumentStatus.toDo)
          item,
    ];
    final inReview = items.where((item) => item.status == DocumentStatus.sent).length;

    if (toFix.isNotEmpty) {
      String reason(DocumentItem item) => switch (item.status) {
        DocumentStatus.rejected => l.docRejected,
        DocumentStatus.expired => l.docExpired,
        _ => l.docToDo,
      };
      return Container(
        decoration: BoxDecoration(
          color: c.dangerTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.dangerText.withValues(alpha: .35)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(icon: TaraIcons.alertCircle, tone: TintTone.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.docsToFix(toFix.length),
                          style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        for (final item in toFix)
                          Text(
                            '${item.main.label(language)} · ${reason(item)}',
                            style: TaraText.small.copyWith(color: c.dangerTextStrong, fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 4),
                        Text(l.docsToFixHint, style: TaraText.small.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: l.sendAgain,
              icon: TaraIcons.camera,
              height: 48,
              radius: 14,
              color: c.accentText,
              onPressed: onOpen,
            ),
          ],
        ),
      );
    }
    final (icon, tone, text) = inReview > 0
        ? (TaraIcons.clock, TintTone.accent, l.docsInReview(inReview))
        : (TaraIcons.shieldCheck, TintTone.success, l.docsAllApproved);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListRow(
        leading: IconTile(icon: icon, tone: tone),
        title: text,
        subtitle: l.progressCount(state.doneCount, state.requirements.length),
        trailing: TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
        onTap: onOpen,
      ),
    );
  }
}

/// En-tête de la maquette : avatar dans un anneau dégradé qui tourne (6 s), nom,
/// véhicule et plaque, état du compte.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.profile});
  final String? name;
  final RiderProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final rider = profile;
    final vehicle = switch (rider?.vehicleType) {
      'MOTORBIKE' => l.vehicleMotorbike,
      'CAR' => l.vehicleCar,
      'TRICYCLE' => l.vehicleTricycle,
      _ => null,
    };
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final status = switch (rider?.status) {
      'ACTIVE' => (l.accountActive, ok),
      'SUSPENDED' => (l.accountSuspended, c.dangerText),
      'REJECTED' => (l.accountRejected, c.dangerText),
      null => null,
      _ => (l.accountPending, c.accentText),
    };
    return Row(
      children: [
        SizedBox.square(
          dimension: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MotionBuilder(
                period: const Duration(seconds: 6),
                stillPhase: 0,
                builder: (context, t, _) => Transform.rotate(
                  angle: t * 2 * math.pi,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, Color(0x00FF3D00), TaraBrand.amber],
                        stops: [0, .25, .5, .7, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: RiderAvatar(name: name ?? '', size: 56),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    (name ?? '').isEmpty ? '—' : name!,
                    style: TextStyle(
                      fontFamily: TaraText.sora,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (vehicle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [vehicle, ?rider?.plateNumber].join(' · '),
                    style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .66)),
                  ),
                ],
                if (status != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: status.$2.withValues(alpha: .14),
                      border: Border.all(color: status.$2.withValues(alpha: .35)),
                    ),
                    child: Text(
                      status.$1,
                      style: TaraText.small.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: status.$2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne du menu de la maquette : pastille d'icône, titre, sous-titre, chevron, filet.
class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.subtitleColor,
  });

  final TaraIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.textPrimary.withValues(alpha: .08))),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 177, 92, .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: TaraIcon(icon, size: 19, strokeWidth: 1.9, color: c.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TaraText.bodyStrong.copyWith(
                        fontSize: 14,
                        color: danger ? (c.isDark ? const Color(0xFFFF6B75) : c.dangerText) : c.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TaraText.small.copyWith(
                        fontSize: 12,
                        color: subtitleColor ?? c.textPrimary.withValues(alpha: .62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textPrimary.withValues(alpha: .4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Conditions et confidentialité » : version acceptée, ou nouvelle version à accepter.
class _TermsLine extends ConsumerWidget {
  const _TermsLine({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final status = ref.watch(termsStatusProvider).value;
    final accepted = status?.accepted.where((item) => item.document == 'livreurs').firstOrNull;
    final toSign = status != null && !status.upToDate;
    return _MenuLine(
      icon: TaraIcons.shield,
      title: l.termsSection,
      subtitle: toSign
          ? l.termsRowToSign
          : accepted == null
          ? l.termsTitle
          : l.termsRowAccepted(accepted.version, formatLegalDay(context, accepted.acceptedAt)),
      subtitleColor: toSign ? c.accentText : null,
      onTap: onTap,
    );
  }
}

/// Page ouverte depuis le menu : retour, titre, contenu.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.onBack, required this.child});
  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return TaraScreen(
      safeBottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Numéro masqué au milieu : « 6 99 •• •• 21 ».
String maskedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final national = digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  if (national.length < 9) return displayPhone(phone);
  return '${national[0]} ${national.substring(1, 3)} •• •• ${national.substring(7)}';
}

/// Réglages d'affichage. Sur le profil (maquette) : thème, transparence des barres et
/// animations, sans cadre. Sur la page « Langue et sons » : langue et sons.
class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.settings, required this.onLanguage, this.languageAndSounds = false});
  final AppSettings settings;
  final ValueChanged<String?> onLanguage;
  final bool languageAndSounds;

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
          style: TaraText.small.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: c.textPrimary.withValues(alpha: .66),
          ),
        ),
        const SizedBox(height: 6),
        control,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint, style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ],
    );
    return ListenableBuilder(
      listenable: Listenable.merge([effects, settings]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: languageAndSounds
            ? [
                setting(
                  l.languageLabel,
                  LiquidSegmented<String>(
                    compact: true,
                    segments: [('auto', l.optionAuto), ('fr', 'Français'), ('en', 'English')],
                    selected: settings.locale?.languageCode ?? 'auto',
                    onChanged: (code) => onLanguage(code == 'auto' ? null : code),
                  ),
                ),
                const SizedBox(height: 20),
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
              ]
            : [
                setting(
                  l.themeLabel,
                  LiquidSegmented<ThemeMode>(
                    compact: true,
                    segments: [
                      (ThemeMode.light, l.themeLight),
                      (ThemeMode.dark, l.themeDark),
                      (ThemeMode.system, l.themeAuto),
                    ],
                    selected: settings.themeMode,
                    onChanged: (mode) => settings.themeMode = mode,
                  ),
                ),
                const SizedBox(height: 14),
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
                ),
                const SizedBox(height: 14),
                setting(
                  l.effectsLabel,
                  // Deux choix comme la maquette ; « automatique » montre ce qui s'applique.
                  LiquidSegmented<bool>(
                    compact: true,
                    segments: [(false, l.effectsAll), (true, l.effectsReduced)],
                    selected: effects.reduced,
                    onChanged: (reduced) =>
                        effects.preference = reduced ? EffectsPreference.reduced : EffectsPreference.full,
                  ),
                ),
              ],
      ),
    );
  }
}

/// Déconnexion, confirmée ; refusée pendant une course ou avec des actions pas encore
/// envoyées (elles seraient perdues).
class _LogoutBlock extends StatelessWidget {
  const _LogoutBlock({
    required this.blocked,
    required this.confirming,
    required this.busy,
    required this.onLogout,
    required this.onCancel,
  });
  final String? blocked;
  final bool confirming;
  final bool busy;
  final VoidCallback onLogout;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final reason = blocked;
    if (reason != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassButton(label: l.logout, icon: TaraIcons.power, onPressed: null),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
        ],
      );
    }
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
                child: GlassButton(label: l.cancel, height: 48, radius: 14, onPressed: busy ? null : onCancel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: busy
                    ? const SizedBox(height: 48, child: Center(child: GooLoader(compact: true)))
                    : GlassButton(label: l.logout, height: 48, radius: 14, color: c.dangerText, onPressed: onLogout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(l.profileError, style: TaraText.label.copyWith(color: c.textSecondary)),
          ),
          TaraLink(label: l.retry, onPressed: onRetry),
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
/// version à signer.
class _TermsCard extends ConsumerWidget {
  const _TermsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final status = ref.watch(termsStatusProvider).value;
    Widget row(String document, String title) {
      final accepted = status?.accepted.where((item) => item.document == document).firstOrNull;
      return ListRow(
        leading: const IconTile(icon: TaraIcons.shieldCheck),
        title: title,
        subtitle: accepted == null
            ? null
            : l.termsAcceptedOn(accepted.version, formatLegalDay(context, accepted.acceptedAt)),
        trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
        onTap: () => unawaited(
          Navigator.of(context).push(
            scopedPage<void>(context, (_) => LegalTextScreen(document: document, acceptedAt: accepted?.acceptedAt)),
          ),
        ),
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
              onTap: () => unawaited(openTermsUpdate(context, ref)),
            ),
          row('livreurs', l.termsTitle),
          row(LegalApi.privacyDocument, l.termsPrivacyTitle),
        ],
      ),
    );
  }
}
