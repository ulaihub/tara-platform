import type { FC } from 'hono/jsx';

/** Version de MapLibre dans l'adresse des fichiers : un nouveau moteur ne sert pas l'ancien cache. */
export const MAP_VERSION = '6.15.0';

/** Douala (centre) : la carte de « Mon point » s'ouvre ici avant la position du téléphone. */
const DOUALA = { latitude: 4.0511, longitude: 9.7043 };

type Point = { latitude: number; longitude: number };

const pair = (p: Point | null | undefined) => (p ? `${p.latitude},${p.longitude}` : undefined);

/**
 * Vraie carte (rues de Douala, style des apps), posée sur la ville dessinée : elle n'apparaît
 * qu'une fois chargée. Sans WebGL ou sans réseau, la ville dessinée reste.
 * `track` : point de livraison et livreur ; `place` : l'épingle du centre choisit le point.
 */
export const RealMap: FC<{
  kind: 'track' | 'place';
  label: string;
  dropoff?: Point | null;
  rider?: Point | null;
  youLabel?: string;
}> = ({ kind, label, dropoff, rider, youLabel }) => (
  <>
    <div
      id="carte"
      class={`realmap ${kind}`}
      role="img"
      aria-label={label}
      data-kind={kind}
      data-dropoff={pair(kind === 'place' ? (dropoff ?? DOUALA) : dropoff)}
      data-rider={pair(rider)}
      data-you={youLabel}
      data-v={MAP_VERSION}
    />
    {/* Voile en haut de la carte : l'en-tête Tara reste lisible sur les rues. */}
    <i class={`map-veil ${kind}`} aria-hidden="true" />
  </>
);

export const REALMAP_CSS = `
/* #carte : plus fort que .maplibregl-map{position:relative} de MapLibre. */
#carte.realmap{position:absolute;left:0;right:0;top:0;opacity:0;transition:opacity .4s ease;background:var(--map-bg)}
.realmap.track{height:380px}.realmap.place{height:470px}
#carte.realmap.ready{opacity:1}
.realmap .maplibregl-ctrl-attrib{font-size:10px}
.realmap .maplibregl-ctrl-bottom-right{bottom:56px}
.map-veil{position:absolute;left:0;right:0;top:0;height:96px;pointer-events:none;opacity:0;transition:opacity .4s ease;background:linear-gradient(180deg,var(--bg) 0%,rgba(var(--bg-rgb),.85) 45%,rgba(var(--bg-rgb),0) 100%)}
#carte.ready+.map-veil{opacity:1}
.realmap.ready~.vignette,.realmap.ready~.fade{z-index:1}
`;

/**
 * Charge MapLibre après la page (module servi ici), puis :
 * - suivi : point de livraison et livreur, mis à jour quand la page relit l'état ;
 * - mon point : la carte bouge sous l'épingle fixe ; un déplacement à la main remplit le
 *   formulaire (sans précision GPS) ; la position du téléphone recentre la carte.
 */
export const MAP_SCRIPT = `(function(){var el=document.getElementById("carte");if(!el||!window.fetch)return;var c=document.createElement("canvas");var gl=null;try{gl=c.getContext("webgl2")||c.getContext("webgl")}catch(e){}if(!gl)return;var d=el.dataset,v=d.v;function pt(s){if(!s)return null;var a=s.split(",").map(Number);return [a[1],a[0]]}var drop=pt(d.dropoff),rider=pt(d.rider),place=d.kind==="place";var dark=window.matchMedia&&matchMedia("(prefers-color-scheme: dark)").matches;import("/carte/maplibre-gl.mjs?v="+v).then(function(m){m.setWorkerUrl("/carte/maplibre-gl-worker.mjs?v="+v);var map=new m.Map({container:el,style:"/carte/style-"+(dark?"sombre":"clair")+".json?v="+v,center:drop||[9.7043,4.0511],zoom:place?(d.dropoff?13:12):15,padding:place?{top:30,bottom:0,left:0,right:0}:{top:40,bottom:60,left:0,right:0},attributionControl:{compact:true},dragRotate:false,pitchWithRotate:false,touchPitch:false});map.touchZoomRotate.disableRotation();function fc(f){return{type:"FeatureCollection",features:f}}function pf(c,p){return{type:"Feature",geometry:{type:"Point",coordinates:c},properties:p||{}}}function riderTo(c){var s=map.getSource("tara-rider");if(s)s.setData(fc(c?[pf(c)]:[]))}map.on("load",function(){el.classList.add("ready");var at=el.querySelector(".maplibregl-compact-show");if(at)at.classList.remove("maplibregl-compact-show");if(place){map.setPadding({top:30,bottom:0,left:0,right:0});return}var st=map.getSource("tara-stop");if(st&&drop)st.setData(fc([pf(drop,{kind:"dropoff",label:d.you||""})]));riderTo(rider);if(drop&&rider){var b=new m.LngLatBounds(drop,drop).extend(rider);map.fitBounds(b,{padding:{top:100,bottom:110,left:50,right:50},maxZoom:16,duration:0})}});document.addEventListener("tara:etat",function(e){var p=e.detail&&e.detail.p;riderTo(p?[p[1],p[0]]:null)});if(place){var f=document.getElementById("place");map.on("moveend",function(e){if(!e.originalEvent||!f)return;var c=map.getCenter();f.latitude.value=c.lat.toFixed(6);f.longitude.value=c.lng.toFixed(6);f.accuracy.value="";document.dispatchEvent(new CustomEvent("tara:manual"))});document.addEventListener("tara:position",function(e){var p=e.detail;if(p)map.jumpTo({center:[p.lng,p.lat],zoom:Math.max(map.getZoom(),17)})})}}).catch(function(){})})();`;
