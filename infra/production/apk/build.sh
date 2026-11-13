#!/usr/bin/env bash
# Construit une app (APP=rider ou client) pointant vers API_URL, en une seule APK pour tous
# les téléphones Android 8+, signée avec la clé de test (installation hors Google Play).
set -euo pipefail
: "${APP:?rider ou client}" "${API_URL:?}"
work=/tmp/tara
rm -rf "$work" && mkdir -p "$work"
# Copie du code (le dépôt est monté en lecture seule).
cp -r /src/apps /src/packages "$work"/
rm -rf "$work"/apps/{api,backoffice,tracking}
cd "$work/apps/$APP"
flutter pub get --enforce-lockfile
flutter build apk --release --dart-define=TARA_API_URL="$API_URL"
name=$([[ $APP == rider ]] && echo tara-livreur || echo tara-expediteur)
cp build/app/outputs/flutter-apk/app-release.apk "/out/$name.apk"
echo "OK : /out/$name.apk ($(du -h "/out/$name.apk" | cut -f1))"
