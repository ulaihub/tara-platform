import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/session/session_store.dart';

/// Extrait des conditions des expéditeurs : titres, liste, tableau et gras, comme le texte réel.
const sampleTerms = '''
# Conditions générales d'utilisation de Tara — expéditeurs

Version 2026-11 · Projet à faire valider par un juriste avant publication.

## 8. Si la livraison échoue

Vous êtes prévenu tout de suite et vous choisissez dans les **15 minutes** :

- **une nouvelle tentative** : le livreur repasse chez le destinataire ;
- **le retour du colis** : le livreur vous le rapporte à l'adresse d'enlèvement.

| Situation          | Frais                                  |
| ------------------ | -------------------------------------- |
| Nouvelle tentative | 500 FCFA                               |
| Retour du colis    | la moitié du prix de base de la course |

- **Retour : pas de paiement, pas de colis.** Ce que votre solde ne couvre pas, vous le payez au
  livreur au moment où il vous rend le colis.
''';

const samplePrivacy = '''
# Politique de confidentialité de Tara

Version 2026-11 · Projet à faire valider par un juriste.

## Vos droits

Depuis l'application, vous pouvez **télécharger toutes vos données** ou **supprimer votre compte**.
''';

final upToDate = TermsStatus(
  required: const {},
  accepted: [
    AcceptedTerms(document: 'expediteurs', version: '2026-11', acceptedAt: DateTime.utc(2026, 11, 3, 9)),
    AcceptedTerms(document: 'confidentialite', version: '2026-11', acceptedAt: DateTime.utc(2026, 11, 3, 9)),
  ],
);

final newVersion = TermsStatus(required: const {'expediteurs': '2026-12'}, accepted: upToDate.accepted);

/// Conditions sans réseau : textes d'exemple, signature enregistrée.
class FakeLegalApi extends LegalApi {
  FakeLegalApi({TermsStatus? status})
    : status0 = status ?? upToDate,
      super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
        app: 'client',
      );

  TermsStatus status0;
  int codes = 0;
  final signed = <({String code, Map<String, String> versions})>[];

  /// Erreur renvoyée à la signature (code faux, version dépassée).
  ApiException? acceptError;

  @override
  Future<LegalDocument> document(String name) async => LegalDocument(
    document: name,
    version: '2026-11',
    title: name,
    markdown: name == LegalApi.privacyDocument ? samplePrivacy : sampleTerms,
  );

  @override
  Future<TermsStatus> status() async => status0;

  @override
  Future<OtpChallenge> requestCode() async {
    codes++;
    return OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000cc',
      expiresAt: DateTime.utc(2026, 11, 3, 10),
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<void> accept({
    required String challengeId,
    required String code,
    required Map<String, String> versions,
  }) async {
    if (acceptError case final error?) throw error;
    signed.add((code: code, versions: versions));
    status0 = upToDate;
  }
}
