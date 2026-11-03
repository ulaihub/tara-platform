#!/usr/bin/env bash
# Prépare les données d'itinéraires OSRM pour le Cameroun (à lancer une fois, puis à
# chaque mise à jour de la carte). Durée : quelques minutes ; espace disque : environ 1 Go.
#
# Source : extrait OpenStreetMap du Cameroun publié par Geofabrik.
# Profil : « car » d'OSRM en attendant un profil moto dédié (voir docs/ARCHITECTURE.md).
set -euo pipefail

cd "$(dirname "$0")"

IMAGE="ghcr.io/project-osrm/osrm-backend:v6.0.0"
EXTRACT_URL="https://download.geofabrik.de/africa/cameroon-latest.osm.pbf"
DATA_DIR="$PWD/data"

mkdir -p "$DATA_DIR"

if [[ ! -f "$DATA_DIR/cameroon-latest.osm.pbf" ]]; then
  echo "Téléchargement de l'extrait OpenStreetMap du Cameroun…"
  curl --fail --location --output "$DATA_DIR/cameroon-latest.osm.pbf" "$EXTRACT_URL"
fi

run() {
  docker run --rm -t -v "$DATA_DIR:/data" "$IMAGE" "$@"
}

echo "Extraction du réseau routier…"
run osrm-extract -p /opt/car.lua /data/cameroon-latest.osm.pbf
echo "Partitionnement…"
run osrm-partition /data/cameroon-latest.osrm
echo "Personnalisation…"
run osrm-customize /data/cameroon-latest.osrm

echo "Terminé. Lancer le service : docker compose -f infra/docker-compose.yml --profile routing up -d osrm"
