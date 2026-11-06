'use client';

import 'maplibre-gl/dist/maplibre-gl.css';
import type { GeoJSONSource, Map as MapLibreMap, Marker } from 'maplibre-gl';
import { useEffect, useRef, useState } from 'react';
import {
  type Collection,
  DOUALA,
  type RiderProps,
  type Selection,
  courseData,
  glide,
  ordersData,
  ridersData,
  taraStyle,
} from '@/lib/map-data';
import type { LiveMap, RiderTrail } from '@/lib/schemas';

/** Durée du glissement d'un livreur vers sa nouvelle position, et rythme des images. */
const GLIDE_MS = 1_400;
const FRAME_MS = 60;

/** Couleurs des états (les mêmes que les pastilles du panneau). */
const COLORS = {
  free: '#12805a',
  course: '#ff6a00',
  offline: '#9a9187',
  late: '#d93025',
  stroke: '#ffffff',
};

/** Sources et calques propres au back-office, ajoutés au style Tara des apps. */
function addLayers(map: MapLibreMap): void {
  const empty = { type: 'FeatureCollection' as const, features: [] };
  map.addSource('bo-orders', { type: 'geojson', data: empty });
  map.addSource('bo-riders', { type: 'geojson', data: empty });
  map.addSource('bo-traveled', { type: 'geojson', data: empty });
  // Chemin déjà parcouru : sous l'itinéraire restant, plus discret.
  map.addLayer(
    {
      id: 'bo-traveled-line',
      type: 'line',
      source: 'bo-traveled',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': '#8a4b1f',
        'line-opacity': 0.55,
        'line-width': ['interpolate', ['exponential', 1.5], ['zoom'], 12, 2.5, 18, 6],
      },
    },
    'tara-route-case',
  );
  map.addLayer({
    id: 'bo-orders-dot',
    type: 'circle',
    source: 'bo-orders',
    paint: {
      'circle-radius': ['case', ['get', 'selected'], 8, 5.5],
      'circle-color': [
        'case',
        ['get', 'late'],
        COLORS.late,
        ['==', ['get', 'stop'], 'pickup'],
        '#16120e',
        COLORS.stroke,
      ],
      'circle-stroke-color': ['case', ['get', 'late'], COLORS.stroke, COLORS.course],
      'circle-stroke-width': ['case', ['==', ['get', 'stop'], 'pickup'], 2, 3],
    },
  });
  map.addLayer({
    id: 'bo-riders-halo',
    type: 'circle',
    source: 'bo-riders',
    filter: ['any', ['==', ['get', 'state'], 'ON_COURSE'], ['get', 'selected']],
    paint: {
      'circle-radius': ['case', ['get', 'selected'], 22, 15],
      'circle-color': COLORS.course,
      'circle-opacity': ['case', ['get', 'selected'], 0.3, 0.16],
    },
  });
  map.addLayer({
    id: 'bo-riders-dot',
    type: 'circle',
    source: 'bo-riders',
    paint: {
      'circle-radius': ['case', ['get', 'selected'], 9.5, 7],
      'circle-color': [
        'match',
        ['get', 'state'],
        'FREE',
        COLORS.free,
        'ON_COURSE',
        COLORS.course,
        COLORS.offline,
      ],
      'circle-opacity': ['case', ['get', 'signalLost'], 0.45, 1],
      'circle-stroke-color': ['case', ['get', 'signalLost'], COLORS.late, COLORS.stroke],
      'circle-stroke-width': 2.5,
    },
  });
  map.addLayer({
    id: 'bo-riders-label',
    type: 'symbol',
    source: 'bo-riders',
    minzoom: 13.5,
    layout: {
      'text-field': ['get', 'label'],
      'text-font': ['Noto Sans Bold'],
      'text-size': 12,
      'text-anchor': 'top',
      'text-offset': [0, 1.1],
    },
    paint: { 'text-color': '#1f1a15', 'text-halo-color': '#ffffff', 'text-halo-width': 1.6 },
  });
}

function setData(map: MapLibreMap, source: string, data: object): void {
  // Mise à jour asynchrone de la source : la prochaine donnée remplace celle-ci de toute façon.
  void (map.getSource(source) as GeoJSONSource | undefined)?.setData(
    data as Parameters<GeoJSONSource['setData']>[0],
  );
}

/**
 * Carte de la ville : livreurs (vert libre, orange en course, gris hors ligne, pâle et
 * cerclé de rouge sans signal), prochain arrêt des commandes (rouge en retard), SOS qui
 * clignotent. La commande choisie montre vendeur, client et trajet du livreur.
 */
export function MapView({
  data,
  selection,
  trail,
  focus,
  onSelect,
}: {
  data: LiveMap;
  selection: Selection;
  /** Course du livreur choisi (chemin parcouru, itinéraire restant), quand elle est arrivée. */
  trail: RiderTrail | null;
  /** Points à cadrer (choix dans le panneau) ; change de référence à chaque demande. */
  focus: { points: { latitude: number; longitude: number }[] } | null;
  onSelect: (selection: Selection) => void;
}) {
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markers = useRef(new Map<string, Marker>());
  const select = useRef(onSelect);
  const [styleVersion, setStyleVersion] = useState(0);
  const [failed, setFailed] = useState(false);
  /** Position affichée de chaque livreur, point de départ du prochain glissement. */
  const shown = useRef(new Map<string, [number, number]>());
  const frame = useRef<number | null>(null);

  useEffect(() => {
    select.current = onSelect;
  }, [onSelect]);

  useEffect(() => {
    let disposed = false;
    const scheme = window.matchMedia('(prefers-color-scheme: dark)');
    const sosMarkers = markers.current;
    import('maplibre-gl')
      .then(({ Map, NavigationControl, setWorkerUrl }) => {
        if (disposed || !container.current) return;
        // Fichier de calcul copié dans public/ (scripts/copy-map-worker.mjs).
        setWorkerUrl('/maplibre-gl-worker.mjs');
        const map = new Map({
          container: container.current,
          style: taraStyle(scheme.matches),
          center: DOUALA.center,
          zoom: DOUALA.zoom,
          attributionControl: { compact: true },
          dragRotate: false,
          pitchWithRotate: false,
        });
        mapRef.current = map;
        map.addControl(new NavigationControl({ showCompass: false }), 'bottom-right');
        map.on('style.load', () => {
          addLayers(map);
          setStyleVersion((version) => version + 1);
        });
        for (const layer of ['bo-riders-dot', 'bo-orders-dot']) {
          map.on('click', layer, (event) => {
            const id = event.features?.[0]?.properties['id'] as string | undefined;
            if (id) select.current({ type: layer === 'bo-riders-dot' ? 'rider' : 'order', id });
          });
          map.on('mouseenter', layer, () => (map.getCanvas().style.cursor = 'pointer'));
          map.on('mouseleave', layer, () => (map.getCanvas().style.cursor = ''));
        }
      })
      .catch(() => setFailed(true));
    const onScheme = () => mapRef.current?.setStyle(taraStyle(scheme.matches), { diff: false });
    scheme.addEventListener('change', onScheme);
    return () => {
      disposed = true;
      scheme.removeEventListener('change', onScheme);
      if (frame.current !== null) cancelAnimationFrame(frame.current);
      for (const marker of sosMarkers.values()) marker.remove();
      sosMarkers.clear();
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  // Données rafraîchies ou choix changé : sources mises à jour, SOS ajoutés ou retirés.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || styleVersion === 0) return;
    moveRiders(map, ridersData(data, selection));
    setData(map, 'bo-orders', ordersData(data, selection));

    const open = new Set(data.safetyAlerts.map((alert) => alert.id));
    for (const [id, marker] of markers.current) {
      if (!open.has(id)) {
        marker.remove();
        markers.current.delete(id);
      }
    }
    void import('maplibre-gl').then(({ Marker: MarkerClass }) => {
      for (const alert of data.safetyAlerts) {
        const existing = markers.current.get(alert.id);
        if (existing) {
          existing.setLngLat([alert.longitude, alert.latitude]);
          continue;
        }
        const element = document.createElement('button');
        element.type = 'button';
        element.className = 'sos-marker';
        element.setAttribute('aria-label', `Alerte SOS de ${alert.riderName ?? 'livreur'}`);
        element.textContent = 'SOS';
        element.addEventListener('click', (event) => {
          event.stopPropagation();
          select.current({ type: 'sos', id: alert.id });
        });
        const marker = new MarkerClass({ element })
          .setLngLat([alert.longitude, alert.latitude])
          .addTo(map);
        markers.current.set(alert.id, marker);
      }
    });
  }, [data, selection, styleVersion]);

  // Course choisie : vendeur, client, itinéraire sur les rues et chemin parcouru.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || styleVersion === 0) return;
    const { stops, route, traveled } = courseData(data, selection, trail);
    setData(map, 'tara-stop', stops);
    setData(map, 'tara-route', route);
    setData(map, 'bo-traveled', traveled);
  }, [data, selection, trail, styleVersion]);

  /**
   * Les livreurs glissent de leur position affichée à la nouvelle (sauf au premier
   * affichage, pour un grand saut, ou si l'ordinateur demande moins d'animations).
   */
  function moveRiders(map: MapLibreMap, target: Collection<RiderProps>): void {
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    const from = new Map(shown.current);
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const remember = (collection: Collection<RiderProps>) => {
      shown.current = new Map(
        collection.features.flatMap((feature) =>
          feature.geometry.type === 'Point'
            ? [[feature.properties.id, feature.geometry.coordinates] as [string, [number, number]]]
            : [],
        ),
      );
    };
    if (still || from.size === 0) {
      setData(map, 'bo-riders', target);
      remember(target);
      return;
    }
    const start = performance.now();
    let drawn = 0;
    const step = (now: number) => {
      const t = Math.min(1, (now - start) / GLIDE_MS);
      if (t === 1 || now - drawn >= FRAME_MS) {
        drawn = now;
        const current = glide(from, target, t);
        setData(map, 'bo-riders', current);
        remember(current);
      }
      frame.current = t < 1 ? requestAnimationFrame(step) : null;
    };
    frame.current = requestAnimationFrame(step);
  }

  useEffect(() => {
    const map = mapRef.current;
    const [first, ...others] = focus?.points ?? [];
    if (!map || !first) return;
    if (others.length === 0) {
      map.flyTo({
        center: [first.longitude, first.latitude],
        zoom: Math.max(map.getZoom(), 14.5),
        speed: 1.6,
      });
      return;
    }
    const points = [first, ...others];
    const longitudes = points.map((point) => point.longitude);
    const latitudes = points.map((point) => point.latitude);
    map.fitBounds(
      [
        [Math.min(...longitudes), Math.min(...latitudes)],
        [Math.max(...longitudes), Math.max(...latitudes)],
      ],
      { padding: { top: 110, bottom: 80, left: 260, right: 80 }, maxZoom: 15.5, speed: 1.6 },
    );
  }, [focus]);

  return (
    <div className="absolute inset-0">
      {/* MapLibre impose « position: relative » à son conteneur : il occupe donc tout son parent. */}
      <div ref={container} className="h-full w-full" />
      {failed ? (
        <p className="absolute inset-0 grid place-items-center text-muted">
          La carte ne peut pas s’afficher sur cet ordinateur (WebGL indisponible).
        </p>
      ) : null}
    </div>
  );
}
