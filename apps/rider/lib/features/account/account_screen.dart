import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/app_settings.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/documents_controller.dart';
import '../onboarding/documents_screen.dart';
import 'emergency_contact_screen.dart';

enum _Sub { documents, contact }

/// Profil et réglages (onglet Profil, non dessiné dans la maquette : passation §7) :
/// identité et véhicule, pièces et leur état (une pièce refusée ou expirée se renvoie
/// d'ici), contact d'urgence, affichage (thème, langue, effets), support, déconnexion.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.onTab, this.pickPhoto = pickWithCamera});

  /// Barre d'onglets : 0 accueil, 1 activité, 2 profil.
  final ValueChanged<int> onTab;

  /// Photo d'une pièce à renvoyer (remplacée dans les tests).
  final PickPhoto pickPhoto;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.7), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  late Future<Json> _me = ref.read(riderApiProvider).me();
  _Sub? _sub;
  bool _confirmLogout = false;
  bool _loggingOut = false;

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
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l.tabProfile, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Json>(
                          future: _me,
                          builder: (context, snapshot) => _IdentityCard(
                            name: snapshot.data?['fullName'] as String?,
                            phone: snapshot.data?['phone'] as String?,
                            profile: profile,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SectionHeader(
                          title: l.myDocuments,
                          action: documents.value == null
                              ? null
                              : TaraLink(label: l.seeAll, onPressed: () => setState(() => _sub = _Sub.documents)),
                        ),
                        const SizedBox(height: 8),
                        if (documents.value case final data?)
                          _DocumentsSummary(state: data, onOpen: () => setState(() => _sub = _Sub.documents))
                        else if (documents.hasError)
                          _Failed(onRetry: _reload)
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: GooLoader(compact: true)),
                          ),
                        const SizedBox(height: 20),
                        SectionHeader(title: l.emergencyContactTitle),
                        const SizedBox(height: 8),
                        _ContactCard(
                          profile: profile,
                          onEdit: profile == null ? null : () => setState(() => _sub = _Sub.contact),
                        ),
                        const SizedBox(height: 20),
                        SectionHeader(title: l.displaySection),
                        const SizedBox(height: 8),
                        _DisplayCard(settings: settings, onLanguage: (code) => _setLanguage(settings, code)),
                        if (config?.supportPhone case final support?) ...[
                          const SizedBox(height: 20),
                          SectionHeader(title: l.helpSection),
                          const SizedBox(height: 8),
                          GlassCard(
                            radius: 22,
                            shadow: false,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: ListRow(
                              leading: const IconTile(icon: TaraIcons.headset),
                              title: l.supportTara,
                              subtitle: displayPhone(support),
                              trailing: TaraIcon(TaraIcons.phone, size: 20, color: c.accentText),
                              onTap: () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: support))),
                            ),
                          ),
                        ],
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
                SafeArea(
                  top: false,
                  child: FloatingTabBar(
                    items: [
                      TabItem(TaraIcons.home, l.tabHome),
                      TabItem(TaraIcons.activity, l.tabActivity),
                      TabItem(TaraIcons.user, l.tabProfile),
                    ],
                    current: 2,
                    onSelected: widget.onTab,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_sub == _Sub.documents)
          Positioned.fill(
            child: DocumentsScreen(
              fromProfile: true,
              pickPhoto: widget.pickPhoto,
              onDone: () => setState(() => _sub = null),
            ),
          ),
        if (_sub == _Sub.contact && profile != null)
          Positioned.fill(
            child: EmergencyContactScreen(
              profile: profile,
              onBack: () => setState(() => _sub = null),
              onSaved: (updated) {
                ref.read(documentsControllerProvider.notifier).replaceProfile(updated);
                setState(() => _sub = null);
              },
            ),
          ),
      ],
    );
  }
}

/// Nom, numéro, véhicule et état du compte.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.phone, required this.profile});
  final String? name;
  final String? phone;
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
    final plate = rider?.plateNumber;
    final status = switch (rider?.status) {
      'ACTIVE' => (l.accountActive, TintTone.success),
      'SUSPENDED' => (l.accountSuspended, TintTone.danger),
      'REJECTED' => (l.accountRejected, TintTone.danger),
      null => null,
      _ => (l.accountPending, TintTone.accent),
    };
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InitialsAvatar(name: name ?? '', size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((name ?? '').isEmpty ? '—' : name!, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                  if (phone != null) Text(displayPhone(phone!), style: TaraText.label.copyWith(color: c.textSecondary)),
                  if (vehicle != null)
                    Text([vehicle, ?plate].join(' · '), style: TaraText.label.copyWith(color: c.textSecondary)),
                  if (status != null) ...[const SizedBox(height: 8), InfoPill(label: status.$1, tone: status.$2)],
                ],
              ),
            ),
          ),
        ],
      ),
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

/// Contact d'urgence : prévenu par SMS si le livreur déclenche une alerte.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.profile, required this.onEdit});
  final RiderProfile? profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = profile?.emergencyContactName;
    final phone = profile?.emergencyContactPhone;
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListRow(
        leading: const IconTile(icon: TaraIcons.shield),
        title: name ?? l.emergencyNone,
        subtitle: phone == null ? l.emergencyHelp : displayPhone(phone),
        trailing: onEdit == null ? null : TaraLink(label: phone == null ? l.add : l.edit, onPressed: onEdit),
        onTap: onEdit,
      ),
    );
  }
}

/// Thème, langue et effets : appliqués tout de suite, gardés sur le téléphone.
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
        listenable: effects,
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
          ],
        ),
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
