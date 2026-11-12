import 'dart:async';

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
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../home/home_screen.dart' show walletProvider;
import '../legal/terms_screen.dart';
import '../order/address_editor.dart';
import '../order/pickup_step.dart' show pickupAddressesProvider;
import '../support/support.dart';
import '../wallet/wallet_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final settings = AppSettingsScope.of(context);
    final me = widget.me;
    final support = ref.watch(appConfigProvider).value?.supportPhone;
    final version = ref.watch(appVersionProvider).value;
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + TaraTabShell.bottomInset(context)),
        children: [
          Semantics(
            header: true,
            child: Text(l.tabProfile, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 16),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InitialsAvatar(name: me.fullName ?? '', size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.fullName ?? '', style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                        Text(displayPhone(me.phone), style: TaraText.label.copyWith(color: c.textSecondary)),
                        if (me.merchant case final shop?) ...[
                          const SizedBox(height: 8),
                          InfoPill(label: shop.shopName, tone: TintTone.accent, icon: TaraIcons.package),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _WalletRow(me: me),
          if (me.referralCode case final code?) ...[
            const SizedBox(height: 20),
            SectionHeader(title: l.referralTitle),
            const SizedBox(height: 8),
            TintBox(
              tone: TintTone.accent,
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.referralBody, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
                    const SizedBox(height: 8),
                    SelectableText(
                      code,
                      style: TaraText.titlePanel.copyWith(color: c.accentStrongText, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: l.myAddresses),
          const SizedBox(height: 8),
          const _AddressesCard(),
          const SizedBox(height: 20),
          SectionHeader(title: l.displaySection),
          const SizedBox(height: 8),
          _DisplayCard(settings: settings, onLanguage: (code) => _setLanguage(settings, code)),
          const SizedBox(height: 20),
          SectionHeader(title: l.termsSection),
          const SizedBox(height: 8),
          _TermsCard(phone: me.phone),
          const SizedBox(height: 20),
          SectionHeader(title: l.helpSection),
          const SizedBox(height: 8),
          GlassCard(
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
                if (support != null)
                  ListRow(
                    leading: const IconTile(icon: TaraIcons.headset),
                    title: l.supportTara,
                    subtitle: displayPhone(support),
                    trailing: TaraIcon(TaraIcons.phone, size: 20, color: c.accentText),
                    onTap: () => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: support))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _LogoutBlock(
            confirming: _confirmLogout,
            busy: _loggingOut,
            onLogout: _logout,
            onCancel: () => setState(() => _confirmLogout = false),
          ),
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

/// Sons activés : un exemple se fait entendre aussitôt.
void _toggleSounds(BuildContext context, AppSettings settings) {
  settings.sounds = !settings.sounds;
  if (settings.sounds) TaraFeedback.play(context, TaraSound.received);
}

/// Conditions et confidentialité : version acceptée et date (copie consultable), nouvelle
/// version à signer.
class _TermsCard extends ConsumerWidget {
  const _TermsCard({required this.phone});

  final String phone;

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
              onTap: () => open((route) => TermsScreen.update(phone: phone, onSigned: () => Navigator.of(route).pop())),
            ),
          row('expediteurs', l.termsTitle),
          row(LegalApi.privacyDocument, l.termsPrivacyTitle),
        ],
      ),
    );
  }
}

/// Accès au portefeuille : solde Tara (et ventes à recevoir d'une boutique).
class _WalletRow extends ConsumerWidget {
  const _WalletRow({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final wallet = ref.watch(walletProvider).value;
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListRow(
        leading: const IconTile(icon: TaraIcons.wallet),
        title: l.walletTitle,
        subtitle: wallet == null ? null : l.walletBalanceTile('${formatAmount(wallet.customerBalance)}\u00a0F'),
        trailing: TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
        onTap: () => unawaited(
          Navigator.of(
            context,
          ).push(scopedPage<void>(context, (route) => WalletScreen(me: me, onBack: () => Navigator.of(route).pop()))),
        ),
      ),
    );
  }
}

/// Adresses favorites (A2) : celles qui portent un libellé (Boutique, Maison, Bureau),
/// proposées à l'enlèvement. Ajout sur la carte, retrait après confirmation.
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
                    radius: 14,
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
