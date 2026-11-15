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
# Mémoire de Gradle adaptée au serveur (le projet demande 8 Go, un KVM 1 n'en a que 4) : ce
# réglage du dossier Gradle de l'utilisateur l'emporte sur celui du projet.
ram_mb=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
heap_mb=$((ram_mb / 2 > 4096 ? 4096 : ram_mb / 2))
mkdir -p "$GRADLE_USER_HOME"
cat >"$GRADLE_USER_HOME/gradle.properties" <<PROPS
org.gradle.jvmargs=-Xmx${heap_mb}m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m
org.gradle.workers.max=2
kotlin.daemon.jvmargs=-Xmx1g
PROPS
cd "$work/apps/$APP"
flutter pub get --enforce-lockfile
flutter build apk --release --dart-define=TARA_API_URL="$API_URL"
name=$([[ $APP == rider ]] && echo tara-livreur || echo tara-expediteur)
# Publication sans fichier à moitié écrit : copie à côté, vérification de l'archive, puis
# remplacement d'un coup (un téléchargement en cours finit avec l'ancienne version, intacte).
tmp="/out/.$name.apk.tmp"
cp build/app/outputs/flutter-apk/app-release.apk "$tmp"
unzip -tq "$tmp" >/dev/null || { rm -f "$tmp"; echo "APK abîmée, non publiée" >&2; exit 1; }
mv -f "$tmp" "/out/$name.apk"
echo "OK : /out/$name.apk ($(du -h "/out/$name.apk" | cut -f1))"
