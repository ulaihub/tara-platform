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
import 'inputs.dart';
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
    required this.getCode,
    required this.codeSent,
    required this.sign,
    required this.digitLabel,
    required this.acceptedOn,
    required this.versionLine,
    required this.errorText,
  });

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
  final String getCode;

  /// « Code envoyé au … » (numéro déjà mis en forme).
  final String Function(String phone) codeSent;
  final String sign;
  final String Function(int index) digitLabel;
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
/// case à cocher (non cochée, active une fois les textes lus jusqu'en bas), puis code SMS
/// qui signe l'acceptation.
///
/// Inscription ([onSignup]) : le code de connexion déjà saisi signe ; « Retour » revient au
/// code. Nouvelle version ([api] et [phone]) : un code de signature est envoyé, à saisir
/// ici ; « Plus tard » ([onLater]) remet la signature à plus tard.
class TermsAcceptScreen extends StatefulWidget {
  const TermsAcceptScreen.signup({
    super.key,
    required this.strings,
    required this.load,
    required Future<void> Function(Map<String, String> versions) onAccept,
    this.onBack,
  }) : onSignup = onAccept,
       api = null,
       phone = null,
       onLater = null,
       onSigned = null;

  const TermsAcceptScreen.update({
    super.key,
    required this.strings,
    required this.load,
    required LegalApi this.api,
    required String this.phone,
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

  /// Numéro du compte, déjà mis en forme pour l'affichage.
  final String? phone;
  final VoidCallback? onLater;
  final VoidCallback? onSigned;

  @override
  State<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends State<TermsAcceptScreen> {
  final _code = TextEditingController();
  late Future<List<LegalDocument>> _documents = widget.load();
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
        _error = widget.strings.errorText(error);
        if (error.code == 'TERMS_OUTDATED') {
          // Nouvelle version parue entre-temps : textes relus, case à recocher.
          _checked = false;
          _challenge = null;
          _documents = widget.load();
        }
        if (error.code == 'OTP_EXPIRED' || error.code == 'OTP_TOO_MANY_ATTEMPTS') _challenge = null;
        _code.clear();
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
      final challenge = await widget.api!.requestCode();
      if (mounted) setState(() => _challenge = challenge);
    }),
  );

  void _sign(List<LegalDocument> documents) => unawaited(
    _run(() async {
      await widget.api!.accept(challengeId: _challenge!.challengeId, code: _code.text, versions: versionsOf(documents));
      widget.onSigned?.call();
    }),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = TaraColors.of(context);
    final leading = Row(
      children: [
        if (widget.onBack != null)
          GlassIconButton(icon: TaraIcons.chevronLeft, label: s.back, onPressed: widget.onBack),
        const Spacer(),
        if (widget.onLater != null) TaraLink(label: s.later, onPressed: _busy ? null : widget.onLater),
      ],
    );
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: FutureBuilder<List<LegalDocument>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leading,
                  const Spacer(),
                  _ErrorLine(s.errorText(snapshot.error!)),
                  const SizedBox(height: 16),
                  GlassButton(label: s.retry, onPressed: () => setState(() => _documents = widget.load())),
                  const Spacer(),
                ],
              ),
            );
          }
          final documents = snapshot.data;
          if (documents == null || snapshot.connectionState != ConnectionState.done) {
            return const Center(child: GooLoader(compact: true));
          }
          return TermsReader(
            leading: leading,
            title: _signup ? s.title : s.updateTitle,
            intro: _signup ? s.signupIntro : s.updateIntro,
            documents: [for (final document in documents) document.markdown],
            readHint: s.end,
            footer: (context, readToEnd) => _challenge == null
                ? _AcceptFooter(
                    strings: s,
                    version: documents.first.version,
                    checked: _checked,
                    readToEnd: readToEnd,
                    busy: _busy,
                    error: _error,
                    actionLabel: _signup ? s.createAccount : s.getCode,
                    onChecked: (value) => setState(() => _checked = value),
                    onAccept: () => _accept(documents),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        child: Text(s.codeSent(widget.phone!), style: TaraText.label.copyWith(color: c.textSecondary)),
                      ),
                      CodeCells(
                        length: 6,
                        controller: _code,
                        oneTimeCode: true,
                        cellHeight: 52,
                        digitLabel: s.digitLabel,
                        onCompleted: (_) => _sign(documents),
                      ),
                      if (_error != null)
                        Padding(padding: const EdgeInsets.fromLTRB(8, 10, 8, 0), child: _ErrorLine(_error!)),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: s.sign,
                        loading: _busy,
                        onPressed: _code.text.length == 6 ? () => _sign(documents) : null,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _AcceptFooter extends StatelessWidget {
  const _AcceptFooter({
    required this.strings,
    required this.version,
    required this.checked,
    required this.readToEnd,
    required this.busy,
    required this.error,
    required this.actionLabel,
    required this.onChecked,
    required this.onAccept,
  });

  final TermsStrings strings;
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
    final s = strings;
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
                      TextSpan(text: s.checkPrefix),
                      TextSpan(text: s.checkTerms(version), style: bold),
                      TextSpan(text: s.checkAnd),
                      TextSpan(text: s.checkPrivacy, style: bold),
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
                        child: Text(s.scrollFirst, style: TaraText.label.copyWith(color: c.textSecondary)),
                      ),
                    ],
                  ),
                ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: _ErrorLine(error!)),
        PrimaryButton(label: actionLabel, loading: busy, onPressed: checked && readToEnd ? onAccept : null),
      ],
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
