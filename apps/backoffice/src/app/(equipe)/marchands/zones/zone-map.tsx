'use client';

import 'maplibre-gl/dist/maplibre-gl.css';
import type { GeoJSONSource, Map as MapLibreMap } from 'maplibre-gl';

type GeoJsonData = Parameters<GeoJSONSource['setData']>[0];
import { useActionState, useEffect, useRef, useState } from 'react';
import { cx } from '@/components/ui';
import { DOUALA, taraStyle } from '@/lib/map-data';
import type { AdminZonesMap } from '@/lib/schemas';
import { type ActionState, createZone } from '../actions';

const IDLE: ActionState = { error: null, done: false };
const ORANGE = '#ff6a00';
const KIND_COLOR = [
  'match',
  ['get', 'kind'],
  'SERVICE_AREA',
  ORANGE,
  'NO_MOTORBIKE',
  '#d93025',
  '#8a4b1f',
];
const INPUT =
  'block h-10 w-full rounded-xl border border-line bg-panel px-3 text-[14px] focus:border-accent-line focus:outline-none';

type Point = [number, number];

function draftData(points: Point[]) {
  const features: object[] = points.map((point) => ({
    type: 'Feature',
    properties: { kind: 'point' },
    geometry: { type: 'Point', coordinates: point },
  }));
  if (points.length >= 2) {
    features.push({
      type: 'Feature',
      properties: { kind: 'line' },
      geometry: {
        type: 'LineString',
        coordinates: points.length >= 3 ? [...points, points[0]] : points,
      },
    });
  }
  if (points.length >= 3) {
    features.push({
      type: 'Feature',
      properties: { kind: 'area' },
      geometry: { type: 'Polygon', coordinates: [[...points, points[0]]] },
    });
  }
  return { type: 'FeatureCollection', features } as GeoJsonData;
}

function addLayers(map: MapLibreMap, zones: AdminZonesMap) {
  map.addSource('bo-zones', { type: 'geojson', data: zones as GeoJsonData });
  map.addLayer({
    id: 'bo-zones-fill',
    type: 'fill',
    source: 'bo-zones',
    paint: {
      'fill-color': KIND_COLOR as never,
      'fill-opacity': ['case', ['get', 'active'], 0.1, 0.03],
    },
  });
  map.addLayer({
    id: 'bo-zones-line',
    type: 'line',
    source: 'bo-zones',
    filter: ['==', ['get', 'active'], true],
    paint: { 'line-color': KIND_COLOR as never, 'line-width': 2 },
  });
  map.addLayer({
    id: 'bo-zones-off',
    type: 'line',
    source: 'bo-zones',
    filter: ['==', ['get', 'active'], false],
    paint: { 'line-color': KIND_COLOR as never, 'line-width': 1.5, 'line-dasharray': [2, 2] },
  });
  map.addSource('bo-draft', { type: 'geojson', data: draftData([]) });
  map.addLayer({
    id: 'bo-draft-area',
    type: 'fill',
    source: 'bo-draft',
    filter: ['==', ['get', 'kind'], 'area'],
    paint: { 'fill-color': ORANGE, 'fill-opacity': 0.2 },
  });
  map.addLayer({
    id: 'bo-draft-line',
    type: 'line',
    source: 'bo-draft',
    filter: ['==', ['get', 'kind'], 'line'],
    paint: { 'line-color': ORANGE, 'line-width': 2.5 },
  });
  map.addLayer({
    id: 'bo-draft-points',
    type: 'circle',
    source: 'bo-draft',
    filter: ['==', ['get', 'kind'], 'point'],
    paint: {
      'circle-radius': 6,
      'circle-color': ORANGE,
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 2,
    },
  });
}

/**
 * Carte des zones (H4) : toutes les zones (pointillés = coupée), et le tracé d'une nouvelle
 * zone, un clic par coin. Le serveur vérifie que le contour ne se croise pas.
 */
export function ZoneMap({ zones }: { zones: AdminZonesMap }) {
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const drawingRef = useRef(false);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [drawing, setDrawing] = useState(false);
  const [points, setPoints] = useState<Point[]>([]);
  const [state, save, saving] = useActionState(createZone, IDLE);

  useEffect(() => {
    let disposed = false;
    const scheme = window.matchMedia('(prefers-color-scheme: dark)');
    import('maplibre-gl')
      .then(({ Map, NavigationControl, setWorkerUrl }) => {
        if (disposed || !container.current) return;
        setWorkerUrl('/maplibre-gl-worker.mjs');
        const map = new Map({
          container: container.current,
          style: taraStyle(scheme.matches),
          center: DOUALA.center,
          zoom: DOUALA.zoom - 0.6,
          attributionControl: { compact: true },
          dragRotate: false,
          pitchWithRotate: false,
          doubleClickZoom: false,
        });
        mapRef.current = map;
        map.addControl(new NavigationControl({ showCompass: false }), 'bottom-right');
        map.on('load', () => {
          addLayers(map, zones);
          setReady(true);
        });
        map.on('click', (event) => {
          if (!drawingRef.current) return;
          setPoints((current) => [...current, [event.lngLat.lng, event.lngLat.lat]]);
        });
      })
      .catch(() => setFailed(true));
    return () => {
      disposed = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
    // La carte se crée une fois ; les zones se mettent à jour plus bas.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const source = mapRef.current?.getSource('bo-zones') as GeoJSONSource | undefined;
    if (ready && source) void source.setData(zones as GeoJsonData);
  }, [zones, ready]);

  useEffect(() => {
    const source = mapRef.current?.getSource('bo-draft') as GeoJSONSource | undefined;
    if (ready && source) void source.setData(draftData(points));
  }, [points, ready]);

  useEffect(() => {
    drawingRef.current = drawing;
    const canvas = mapRef.current?.getCanvas();
    if (canvas) canvas.style.cursor = drawing ? 'crosshair' : '';
  }, [drawing]);

  // Zone enregistrée : le tracé s'efface, la zone apparaît avec les autres.
  useEffect(() => {
    if (state.done) {
      setPoints([]);
      setDrawing(false);
    }
  }, [state]);

  return (
    <div>
      <div className="relative overflow-hidden rounded-2xl border border-line">
        <div ref={container} className="h-[520px] w-full bg-panel-soft" />
        {failed ? (
          <p className="absolute inset-0 grid place-items-center text-muted">
            Carte indisponible pour le moment.
          </p>
        ) : null}
        {drawing ? (
          <p className="absolute top-3 left-3 rounded-xl bg-panel px-3 py-2 text-[13px] font-bold shadow-card">
            Cliquez sur la carte pour placer chaque coin de la zone ({points.length} point
            {points.length > 1 ? 's' : ''}).
          </p>
        ) : null}
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-4 text-[12px] text-muted">
        <span className="inline-flex items-center gap-1.5">
          <span className="size-3 rounded-sm border-2 border-[#ff6a00]" /> Zone desservie
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="size-3 rounded-sm border-2 border-[#d93025]" /> Interdite aux motos
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="size-3 rounded-sm border-2 border-[#8a4b1f]" /> Quartier
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="size-3 rounded-sm border-2 border-dashed border-muted" /> Coupée
        </span>
      </div>

      {drawing ? (
        <form
          action={save}
          className="mt-4 rounded-2xl border border-accent-line bg-panel-soft p-4"
        >
          <input type="hidden" name="points" value={JSON.stringify(points)} />
          <div className="grid gap-3 md:grid-cols-[1fr_240px]">
            <label className="block">
              <span className="text-[12px] font-bold text-muted">Nom de la zone</span>
              <input
                name="name"
                required
                placeholder="Marché Central"
                className={cx(INPUT, 'mt-1')}
              />
            </label>
            <label className="block">
              <span className="text-[12px] font-bold text-muted">Type</span>
              <select name="kind" defaultValue="NO_MOTORBIKE" className={cx(INPUT, 'mt-1')}>
                <option value="NO_MOTORBIKE">Interdite aux motos</option>
                <option value="SERVICE_AREA">Zone desservie</option>
                <option value="NEIGHBORHOOD">Quartier</option>
              </select>
            </label>
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <button
              type="submit"
              disabled={saving || points.length < 3}
              className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
            >
              {saving ? 'Enregistrement…' : 'Enregistrer la zone'}
            </button>
            <button
              type="button"
              disabled={points.length === 0}
              onClick={() => setPoints((current) => current.slice(0, -1))}
              className="min-h-10 rounded-xl border border-line px-3 text-[14px] font-bold hover:border-accent-line disabled:opacity-50"
            >
              Retirer le dernier point
            </button>
            <button
              type="button"
              onClick={() => {
                setPoints([]);
                setDrawing(false);
              }}
              className="min-h-10 rounded-xl px-3 text-[14px] font-bold text-muted hover:text-text"
            >
              Annuler
            </button>
          </div>
          {state.error ? (
            <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
              {state.error}
            </p>
          ) : null}
        </form>
      ) : (
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => setDrawing(true)}
            className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand"
          >
            Dessiner une zone
          </button>
          {state.done ? (
            <p role="status" className="text-[13px] font-bold text-ok">
              Zone enregistrée : elle s’applique tout de suite dans les apps.
            </p>
          ) : null}
        </div>
      )}
    </div>
  );
}
