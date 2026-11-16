# tara_sms

Lecture automatique du code reçu par SMS, sur Android, sans permission de lecture des SMS :

- **SMS Retriever** : le SMS se termine par l'empreinte de l'app (11 caractères, réglée sur le
  serveur par `tara apk`) ; Android le remet à l'app sans rien demander.
- **SMS User Consent** (secours, empreinte inconnue du serveur) : Android montre le SMS et
  demande « Autoriser » ; un geste suffit.

Sur iOS, rien à faire : le clavier propose le code reçu (`AutofillHints.oneTimeCode`).
