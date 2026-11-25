'use client';

import 'maplibre-gl/dist/maplibre-gl.css';
import type { GeoJSONSource, Map as MapLibreMap } from 'maplibre-gl';
import { useActionState, useEffect, useRef, useState } from 'react';
import { cx } from '@/components/ui';
import { DOUALA, taraStyle } from '@/lib/map-data';
import type { LandmarkList } from '@/lib/schemas';
import { type ActionState, createLandmark, removeLandmark } from '../actions';

type GeoJsonData = Parameters<GeoJSONSource['setData']>[0];

const IDLE: ActionState = { error: null, done: false };
const INPUT =
  'block h-10 w-full rounded-xl border border-line bg-panel px-3 text-[14px] focus:border-accent-line focus:outline-none';

function landmarksData(items: LandmarkList['items']): GeoJsonData {
  return {
    type: 'FeatureCollection',
    features: items.map((item) => ({
      type: 'Feature',
      properties: { id: item.id, name: item.name },
      geometry: { type: 'Point', coordinates: [item.longitude, item.latitude] },
    })),
  } as GeoJsonData;
}

function draftData(point: [number, number] | null): GeoJsonData {
  return {
    type: 'FeatureCollection',
    features: point
      ? [{ type: 'Feature', properties: {}, geometry: { type: 'Point', coordinates: point } }]
      : [],
  } as GeoJsonData;
}

/**
 * Repères de la carte (carrefours, ronds-points, lieux connus que la carte ne nomme pas) :
 * un clic place le repère, un nom, et il s'affiche dans les apps expéditeur et livreur.
 */
export function LandmarkMap({ landmarks }: { landmarks: LandmarkList }) {
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [point, setPoint] = useState<[number, number] | null>(null);
  const [state, save, saving] = useActionState(createLandmark, IDLE);
  const [removed, remove, removing] = useActionState(removeLandmark, IDLE);

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
          zoom: DOUALA.zoom + 1,
          attributionControl: { compact: true },
          dragRotate: false,
          pitchWithRotate: false,
          doubleClickZoom: false,
        });
        mapRef.current = map;
        map.addControl(new NavigationControl({ showCompass: false }), 'bottom-right');
        map.on('load', () => {
          map.addSource('bo-landmark-draft', { type: 'geojson', data: draftData(null) });
          map.addLayer({
            id: 'bo-landmark-draft',
            type: 'circle',
            source: 'bo-landmark-draft',
            paint: {
              'circle-radius': 8,
              'circle-color': '#ff6a00',
              'circle-stroke-color': '#ffffff',
              'circle-stroke-width': 3,
            },
          });
          map.getCanvas().style.cursor = 'crosshair';
          setReady(true);
        });
        map.on('click', (event) => setPoint([event.lngLat.lng, event.lngLat.lat]));
      })
      .catch(() => setFailed(true));
    return () => {
      disposed = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const source = mapRef.current?.getSource('tara-landmarks') as GeoJSONSource | undefined;
    if (ready && source) void source.setData(landmarksData(landmarks.items));
  }, [landmarks, ready]);

  useEffect(() => {
    const source = mapRef.current?.getSource('bo-landmark-draft') as GeoJSONSource | undefined;
    if (ready && source) void source.setData(draftData(point));
  }, [point, ready]);

  // Repère enregistré : le point provisoire s'efface, le repère apparaît avec les autres.
  useEffect(() => {
    if (state.done) setPoint(null);
  }, [state]);

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_340px]">
      <div>
        <div className="relative overflow-hidden rounded-2xl border border-line">
          <div ref={container} className="h-[560px] w-full bg-panel-soft" />
          {failed ? (
            <p className="absolute inset-0 grid place-items-center text-muted">
              Carte indisponible pour le moment.
            </p>
          ) : (
            <p className="absolute top-3 left-3 rounded-xl bg-panel px-3 py-2 text-[13px] font-bold shadow-card">
              Cliquez à l’endroit exact du repère.
            </p>
          )}
        </div>
        <form
          action={save}
          className="mt-4 rounded-2xl border border-accent-line bg-panel-soft p-4"
        >
          <input type="hidden" name="latitude" value={point?.[1] ?? ''} />
          <input type="hidden" name="longitude" value={point?.[0] ?? ''} />
          <label className="block">
            <span className="text-[12px] font-bold text-muted">Nom du repère</span>
            <input
              name="name"
              required
              minLength={3}
              maxLength={80}
              placeholder="Carrefour Nkongmondo"
              className={cx(INPUT, 'mt-1')}
            />
          </label>
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <button
              type="submit"
              disabled={saving || !point}
              className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
            >
              {saving ? 'Enregistrement…' : 'Ajouter le repère'}
            </button>
            {point ? (
              <span className="text-[12px] text-muted">
                Point placé : {point[1].toFixed(5)}, {point[0].toFixed(5)}
              </span>
            ) : null}
          </div>
          {state.error ? (
            <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
              {state.error}
            </p>
          ) : state.done ? (
            <p role="status" className="mt-2 text-[13px] font-bold text-ok">
              Repère ajouté : il s’affiche dans les apps à leur prochaine ouverture.
            </p>
          ) : null}
        </form>
      </div>

      <section className="bo-glass rounded-[22px] p-5 shadow-card">
        <h2 className="font-display text-[17px] font-bold">
          Repères{' '}
          <span className="text-[14px] font-semibold text-muted">({landmarks.items.length})</span>
        </h2>
        <p className="mb-3 text-[13px] text-muted">
          Ce que la carte ne nomme pas : carrefours, ronds-points, lieux que tout le monde connaît.
        </p>
        {landmarks.items.length === 0 ? (
          <p className="text-[13px] text-muted">Aucun repère pour l’instant.</p>
        ) : (
          <ul className="divide-y divide-line">
            {landmarks.items.map((item) => (
              <li key={item.id} className="flex items-center gap-3 py-2">
                <button
                  type="button"
                  onClick={() =>
                    mapRef.current?.flyTo({ center: [item.longitude, item.latitude], zoom: 16 })
                  }
                  className="flex-1 text-left text-[14px] font-semibold hover:text-accent"
                >
                  {item.name}
                </button>
                <form action={remove}>
                  <input type="hidden" name="id" value={item.id} />
                  <button
                    type="submit"
                    disabled={removing}
                    className="text-[12px] font-bold text-danger hover:underline disabled:opacity-50"
                  >
                    Retirer
                  </button>
                </form>
              </li>
            ))}
          </ul>
        )}
        {removed.error ? (
          <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
            {removed.error}
          </p>
        ) : null}
      </section>
    </div>
  );
}
