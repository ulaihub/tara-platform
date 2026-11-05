import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/check_row.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/legal_markdown.dart';
import 'package:tara_ui/components/terms_reader.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

const _blobs = [
  BlobSpec(alignment: Alignment(1.25, -1.0), size: 280, colors: BlobSpec.brand, blur: 70),
  BlobSpec(alignment: Alignment(-1.3, 0.9), size: 220, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 6)),
];

/// Versions affichées, par document : renvoyées à l'acceptation (refusées si elles ont changé).
Map<String, String> versionsOf(List<LegalDocument> documents) => {
  for (final document in documents) document.document: document.version,
};

/// Conditions des expéditeurs et politique de confidentialité, lues en entier puis
/// acceptées : case à cocher (non cochée), puis code SMS qui signe l'acceptation.
///
/// Inscription ([onSignup]) : le code de connexion déjà saisi signe ; « Retour » revient au
/// code. Nouvelle version ([phone]) : un code de signature est envoyé, à saisir ici ;
/// « Plus tard » ([onLater]) laisse suivre les livraisons en cours, sans nouvelle commande.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen.signup({
    super.key,
    required Future<void> Function(Map<String, String> versions) onAccept,
    this.onBack,
  }) : onSignup = onAccept,
       phone = null,
       onLater = null,
       onSigned = null;

  const TermsScreen.update({super.key, required String this.phone, this.onLater, required this.onSigned})
    : onSignup = null,
      onBack = null;

  final Future<void> Function(Map<String, String> versions)? onSignup;
  final VoidCallback? onBack;
  final String? phone;
  final VoidCallback? onLater;
  final VoidCallback? onSigned;

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  final _code = TextEditingController();
  bool _checked = false;
  bool _busy = false;
  OtpChallenge? _challenge;
  String? _error;

  bool get _signup => widget.onSignup != null;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(context, error);
        if (error.code == 'TERMS_OUTDATED') {
          // Nouvelle version parue entre-temps : textes relus, case à recocher.
          _checked = false;
          _challenge = null;
          ref.invalidate(termsDocumentsProvider);
        }
        if (error.code == 'OTP_EXPIRED' || error.code == 'OTP_TOO_MANY_ATTEMPTS') _challenge = null;
        _code.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _accept(List<LegalDocument> documents) => unawaited(
    _run(() async {
      if (_signup) {
        await widget.onSignup!(versionsOf(documents));
        return;
      }
      final challenge = await ref.read(legalApiProvider).requestCode();
      if (mounted) setState(() => _challenge = challenge);
    }),
  );

  void _sign(List<LegalDocument> documents) => unawaited(
    _run(() async {
      await ref
          .read(legalApiProvider)
          .accept(challengeId: _challenge!.challengeId, code: _code.text, versions: versionsOf(documents));
      ref.invalidate(termsStatusProvider);
      widget.onSigned?.call();
    }),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final documents = ref.watch(termsDocumentsProvider);
    final leading = Row(
      children: [
        if (widget.onBack != null)
          GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
        const Spacer(),
        if (widget.onLater != null) TaraLink(label: l.termsLater, onPressed: _busy ? null : widget.onLater),
      ],
    );
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: switch (documents) {
        AsyncData(:final value) => TermsReader(
          leading: leading,
          title: _signup ? l.termsTitle : l.termsUpdateTitle,
          intro: _signup ? l.termsSignupIntro : l.termsUpdateIntro,
          documents: [for (final document in value) document.markdown],
          readHint: l.termsEnd,
          footer: (context, readToEnd) => _challenge == null
              ? _AcceptFooter(
                  version: value.first.version,
                  checked: _checked,
                  readToEnd: readToEnd,
                  busy: _busy,
                  error: _error,
                  actionLabel: _signup ? l.termsCreateAccount : l.termsGetCode,
                  onChecked: (value) => setState(() => _checked = value),
                  onAccept: () => _accept(value),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                      child: Text(
                        l.termsCodeSent(displayPhone(widget.phone!)),
                        style: TaraText.label.copyWith(color: c.textSecondary),
                      ),
                    ),
                    CodeCells(
                      length: 6,
                      controller: _code,
                      oneTimeCode: true,
                      cellHeight: 52,
                      digitLabel: l.digitLabel,
                      onCompleted: (_) => _sign(value),
                    ),
                    if (_error != null)
                      Padding(padding: const EdgeInsets.fromLTRB(8, 10, 8, 0), child: ErrorLine(_error!)),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: l.termsSign,
                      loading: _busy,
                      onPressed: _code.text.length == 6 ? () => _sign(value) : null,
                    ),
                  ],
                ),
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              const Spacer(),
              ErrorLine(errorMessage(context, error)),
              const SizedBox(height: 16),
              GlassButton(label: l.retry, onPressed: () => ref.invalidate(termsDocumentsProvider)),
              const Spacer(),
            ],
          ),
        ),
        _ => const Center(child: GooLoader(compact: true)),
      },
    );
  }
}

class _AcceptFooter extends StatelessWidget {
  const _AcceptFooter({
    required this.version,
    required this.checked,
    required this.readToEnd,
    required this.busy,
    required this.error,
    required this.actionLabel,
    required this.onChecked,
    required this.onAccept,
  });

  final String version;
  final bool checked;
  final bool readToEnd;
  final bool busy;
  final String? error;
  final String actionLabel;
  final ValueChanged<bool> onChecked;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final bold = TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: readToEnd
              ? TaraCheckRow(
                  value: checked,
                  onChanged: busy ? null : onChecked,
                  label: TextSpan(
                    children: [
                      TextSpan(text: l.termsCheckPrefix),
                      TextSpan(text: l.termsCheckTerms(version), style: bold),
                      TextSpan(text: l.termsCheckAnd),
                      TextSpan(text: l.termsCheckPrivacy, style: bold),
                      const TextSpan(text: '.'),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      TaraIcon(TaraIcons.chevronDown, size: 18, color: c.accentText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.termsScrollFirst, style: TaraText.label.copyWith(color: c.textSecondary)),
                      ),
                    ],
                  ),
                ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: ErrorLine(error!)),
        PrimaryButton(label: actionLabel, loading: busy, onPressed: checked && readToEnd ? onAccept : null),
      ],
    );
  }
}

/// Lecture d'un texte (lien de la connexion, profil) : version en vigueur, sans action.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.document, this.acceptedAt});

  /// expediteurs ou confidentialite.
  final String document;

  /// Date d'acceptation à rappeler en tête (profil).
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final text = ref.watch(_documentProvider(document));
    return TaraScreen(
      blobs: _blobs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GlassIconButton(
              icon: TaraIcons.chevronLeft,
              label: l.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(height: 20),
          switch (text) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (acceptedAt case final date?) ...[
                  InfoPill(
                    label: l.termsAcceptedOn(value.version, formatDay(context, date)),
                    tone: TintTone.success,
                    icon: TaraIcons.check,
                  ),
                  const SizedBox(height: 16),
                ],
                LegalMarkdown(value.markdown),
              ],
            ),
            AsyncError(:final error) => ErrorLine(errorMessage(context, error)),
            _ => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: GooLoader(compact: true)),
            ),
          },
          if (text.hasValue) ...[
            const SizedBox(height: 24),
            Text(l.termsVersionLine(text.value!.version), style: TaraText.small.copyWith(color: c.textTertiary)),
          ],
        ],
      ),
    );
  }
}

final _documentProvider = FutureProvider.family<LegalDocument, String>(
  (ref, name) => ref.read(legalApiProvider).document(name),
);

/// « 5 nov. 2026 » dans la langue de l'app.
String formatDay(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
