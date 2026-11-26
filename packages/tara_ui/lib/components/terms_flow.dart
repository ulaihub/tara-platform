import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/api/models.dart';

import '../motion/effects.dart';
import '../motion/liquid_background.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'buttons.dart';
import 'check_row.dart';
import 'glass.dart';
import 'layout.dart';
import 'legal_markdown.dart';
import 'terms_reader.dart';

/// Libellés de l'acceptation des conditions, traduits par chaque app.
class TermsStrings {
  const TermsStrings({
    required this.back,
    required this.retry,
    required this.title,
    required this.updateTitle,
    required this.signupIntro,
    required this.updateIntro,
    required this.later,
    required this.end,
    required this.scrollFirst,
    required this.checkPrefix,
    required this.checkTerms,
    required this.checkAnd,
    required this.checkPrivacy,
    required this.createAccount,
    required this.acceptUpdate,
    required this.acceptedOn,
    required this.versionLine,
    required this.errorText,
    required this.signupKicker,
    required this.readPercent,
  });

  /// Sur-titre de l'inscription (« AVANT DE COMMENCER »).
  final String signupKicker;

  /// « Lu à 40% ».
  final String Function(int percent) readPercent;

  final String back;
  final String retry;
  final String title;
  final String updateTitle;
  final String signupIntro;
  final String updateIntro;
  final String later;
  final String end;
  final String scrollFirst;
  final String checkPrefix;
  final String Function(String version) checkTerms;
  final String checkAnd;
  final String checkPrivacy;
  final String createAccount;

  /// Bouton qui accepte une nouvelle version (« J'accepte »).
  final String acceptUpdate;
  final String Function(String version, String date) acceptedOn;
  final String Function(String version) versionLine;

  /// Message d'une erreur (celui du serveur, ou réseau).
  final String Function(Object error) errorText;
}

const _blobs = [
  BlobSpec(alignment: Alignment(1.25, -1.0), size: 280, colors: BlobSpec.brand, blur: 70),
  BlobSpec(alignment: Alignment(-1.3, 0.9), size: 220, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 6)),
];

/// Versions affichées, par document : renvoyées à l'acceptation (refusées si elles ont changé).
Map<String, String> versionsOf(List<LegalDocument> documents) => {
  for (final document in documents) document.document: document.version,
};

/// « 5 nov. 2026 » dans la langue de l'app.
String formatLegalDay(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.toLocal());

/// Conditions de l'app et politique de confidentialité, lues en entier puis acceptées :
/// case à cocher (non cochée, active une fois les textes lus jusqu'en bas).
///
/// Inscription ([onSignup]) : le code de connexion déjà saisi signe ; « Retour » revient au
/// code. Nouvelle version ([api]) : l'utilisateur est connecté, la case suffit ; « Plus
/// tard » ([onLater]) remet l'acceptation à plus tard.
class TermsAcceptScreen extends StatefulWidget {
  const TermsAcceptScreen.signup({
    super.key,
    required this.strings,
    required this.load,
    required Future<void> Function(Map<String, String> versions) onAccept,
    this.onBack,
  }) : onSignup = onAccept,
       api = null,
       onLater = null,
       onSigned = null;

  const TermsAcceptScreen.update({
    super.key,
    required this.strings,
    required this.load,
    required LegalApi this.api,
    required this.onSigned,
    this.onLater,
  }) : onSignup = null,
       onBack = null;

  final TermsStrings strings;

  /// Textes à afficher : conditions de l'app puis confidentialité.
  final Future<List<LegalDocument>> Function() load;
  final Future<void> Function(Map<String, String> versions)? onSignup;
  final VoidCallback? onBack;
  final LegalApi? api;
  final VoidCallback? onLater;
  final VoidCallback? onSigned;

  @override
  State<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends State<TermsAcceptScreen> {
  late Future<List<LegalDocument>> _documents = widget.load();
  bool _checked = false;
  double _read = 0;
  bool _busy = false;
  String? _error;

  bool get _signup => widget.onSignup != null;

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
        _error = widget.strings.errorText(error);
        if (error.code == 'TERMS_OUTDATED') {
          // Nouvelle version parue entre-temps : textes relus, case à recocher.
          _checked = false;
          _read = 0;
          _documents = widget.load();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = widget.strings.errorText(error));
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
      await widget.api!.accept(versions: versionsOf(documents));
      widget.onSigned?.call();
    }),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = TaraColors.of(context);
    return TaraScreen(
      blobs: _blobs,
      child: FutureBuilder<List<LegalDocument>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GlassIconButton(icon: TaraIcons.chevronLeft, label: s.back, onPressed: widget.onBack),
                    ),
                  const Spacer(),
                  _ErrorLine(s.errorText(snapshot.error!)),
                  const SizedBox(height: 16),
                  GlassButton(label: s.retry, onPressed: () => setState(() => _documents = widget.load())),
                  const Spacer(),
                  if (widget.onLater != null)
                    Center(
                      child: TaraLink(label: s.later, onPressed: widget.onLater),
                    ),
                ],
              ),
            );
          }
          final documents = snapshot.data;
          if (documents == null || snapshot.connectionState != ConnectionState.done) {
            return const Center(child: GooLoader(compact: true));
          }
          final version = documents.first.version;
          final readToEnd = _read >= 1;
          final ready = readToEnd && (_checked || !_signup);
          final intro = Text(
            _signup ? s.signupIntro : s.updateIntro,
            style: TaraText.label.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: c.textPrimary.withValues(alpha: _signup ? .78 : .74),
            ),
          );
          // Maquettes : inscription (retour, « Avant de commencer », titre 18, version) ;
          // nouvelle version (« Version … », titre 26, explication).
          final header = _signup
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      if (widget.onBack != null) ...[
                        GlassIconButton(icon: TaraIcons.chevronLeft, label: s.back, onPressed: widget.onBack),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.signupKicker.toUpperCase(),
                                style: TaraText.overline.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: c.accentText,
                                ),
                              ),
                              Text(s.title, style: TaraText.titlePanel.copyWith(fontSize: 18, color: c.textPrimary)),
                              Text(
                                s.versionLine(version),
                                style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .70)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.versionLine(version).toUpperCase(),
                        style: TaraText.smallStrong.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: c.accentText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        header: true,
                        child: Text(s.updateTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                      ),
                      const SizedBox(height: 6),
                      intro,
                    ],
                  ),
                );
          final disabled = TaraText.buttonSecondary.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: c.textPrimary.withValues(alpha: .42),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, _signup ? 14 : 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_signup) ...[intro, const SizedBox(height: 12)],
                      Expanded(
                        child: TermsReadCard(
                          documents: [for (final document in documents) document.markdown],
                          endLine: s.end,
                          fade: _signup,
                          onProgress: (read) => setState(() => _read = read),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TermsReadBar(read: _read, label: s.readPercent),
                      if (!readToEnd) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Center(
                            child: Text(
                              s.scrollFirst,
                              textAlign: TextAlign.center,
                              style: TaraText.label.copyWith(fontWeight: FontWeight.w800, color: c.accentText),
                            ),
                          ),
                        ),
                      ],
                      if (_signup) ...[
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: readToEnd ? 1 : .45,
                          child: TaraCheckRow(
                            value: _checked,
                            onChanged: readToEnd && !_busy ? (value) => setState(() => _checked = value) : null,
                            label: TextSpan(
                              children: [
                                TextSpan(text: s.checkPrefix),
                                TextSpan(
                                  text: s.checkTerms(version),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: s.checkAnd),
                                TextSpan(
                                  text: s.checkPrivacy,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_error case final error?) ...[const SizedBox(height: 10), _ErrorLine(error)],
                      const SizedBox(height: 12),
                      if (ready || _busy)
                        PrimaryButton(
                          label: _signup ? s.createAccount : s.acceptUpdate,
                          loading: _busy,
                          onPressed: () => _accept(documents),
                        )
                      else
                        // Maquette : bouton gris tant que les textes ne sont pas lus (et cochés).
                        Semantics(
                          button: true,
                          enabled: false,
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: c.textPrimary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(_signup ? s.createAccount : s.acceptUpdate, style: disabled),
                          ),
                        ),
                      if (widget.onLater != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _busy ? null : widget.onLater,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 40),
                              child: Center(
                                child: Text(
                                  s.later,
                                  style: TaraText.text.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary.withValues(alpha: .66),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lecture d'un texte (lien de la connexion, profil) : version en vigueur, sans action.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.strings, required this.load, this.acceptedAt});

  final TermsStrings strings;
  final Future<LegalDocument> Function() load;

  /// Date d'acceptation à rappeler en tête (profil).
  final DateTime? acceptedAt;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<LegalDocument> _text = widget.load();

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = TaraColors.of(context);
    return TaraScreen(
      blobs: _blobs,
      child: FutureBuilder<LegalDocument>(
        future: _text,
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GlassIconButton(
                icon: TaraIcons.chevronLeft,
                label: s.back,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: 20),
            if (snapshot.data case final text?) ...[
              if (widget.acceptedAt case final date?) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: InfoPill(
                    label: s.acceptedOn(text.version, formatLegalDay(context, date)),
                    tone: TintTone.success,
                    icon: TaraIcons.check,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              LegalMarkdown(text.markdown),
              const SizedBox(height: 24),
              Text(s.versionLine(text.version), style: TaraText.small.copyWith(color: c.textTertiary)),
            ] else if (snapshot.hasError) ...[
              _ErrorLine(s.errorText(snapshot.error!)),
              const SizedBox(height: 16),
              GlassButton(label: s.retry, onPressed: () => setState(() => _text = widget.load())),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: GooLoader(compact: true)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'erreur, annoncée par le lecteur d'écran.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: TaraIcon(TaraIcons.alertCircle, size: 16, color: c.dangerText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TaraText.label.copyWith(color: c.dangerText)),
          ),
        ],
      ),
    );
  }
}
