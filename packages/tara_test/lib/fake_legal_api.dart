import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/legal_api.dart';
import 'package:tara_core/api/models.dart';
import 'package:tara_core/session/session_store.dart';

/// Extrait des conditions : titres, liste, tableau et gras, comme le texte réel.
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

/// Conditions de l'app ([app] : client ou rider) et confidentialité acceptées le 3 novembre.
TermsStatus upToDate([String app = 'client']) => TermsStatus(
  required: const {},
  accepted: [
    AcceptedTerms(document: termsOf(app), version: '2026-11', acceptedAt: DateTime.utc(2026, 11, 3, 9)),
    AcceptedTerms(document: 'confidentialite', version: '2026-11', acceptedAt: DateTime.utc(2026, 11, 3, 9)),
  ],
);

/// Nouvelle version des conditions de l'app à accepter.
TermsStatus newVersion([String app = 'client']) =>
    TermsStatus(required: {termsOf(app): '2026-12'}, accepted: upToDate(app).accepted);

String termsOf(String app) => app == 'rider' ? 'livreurs' : 'expediteurs';

/// Conditions sans réseau : textes d'exemple, acceptation enregistrée.
class FakeLegalApi extends LegalApi {
  FakeLegalApi({TermsStatus? status, super.app = 'client'})
    : status0 = status ?? upToDate(app),
      super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
      );

  TermsStatus status0;

  /// Versions envoyées à chaque acceptation.
  final signed = <Map<String, String>>[];

  /// Erreur renvoyée à l'acceptation (version dépassée, réseau).
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
  Future<void> accept({required Map<String, String> versions}) async {
    if (acceptError case final error?) throw error;
    signed.add(versions);
    status0 = upToDate(app);
  }
}
