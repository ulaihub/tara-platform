import type { FC } from 'hono/jsx';

/**
 * Ville en relief de la maquette Web-Suivi, en HTML et CSS seuls (aucune image, aucun
 * script) : un plateau incliné qui oscille lentement, des immeubles en cinq faces, le
 * trajet orange, la moto à la part déjà parcourue et l'épingle « Vous ».
 * La page interdit les styles en ligne : chaque immeuble a sa classe (`CITY_CSS`).
 */

/** Gauche, haut, largeur, profondeur, hauteur, fenêtres éclairées. */
const BUILDINGS: [number, number, number, number, number, boolean][] = [
  [68, 11, 46, 45, 21, false],
  [68, 63, 50, 40, 54, false],
  [11, 147, 47, 40, 74, false],
  [68, 147, 48, 41, 34, true],
  [68, 196, 49, 41, 49, true],
  [11, 273, 44, 31, 18, true],
  [68, 273, 51, 28, 30, true],
  [157, 11, 42, 40, 26, true],
  [157, 63, 48, 43, 34, true],
  [211, 11, 41, 38, 73, true],
  [211, 63, 46, 45, 51, true],
  [157, 147, 47, 41, 69, true],
  [157, 196, 47, 40, 69, true],
  [211, 147, 46, 39, 62, true],
  [211, 196, 44, 42, 20, true],
  [211, 273, 45, 28, 29, true],
  [293, 11, 50, 44, 36, true],
  [293, 63, 56, 45, 22, true],
  [293, 147, 48, 37, 29, true],
  [293, 196, 53, 43, 37, false],
];

const ROUTE = 'M138 20 L 138 128 L 276 128 L 276 256 L 330 256';

/** Part du trajet arrondie au dixième : une classe par cran (pas de style en ligne). */
export const routeStep = (progress: number) => Math.min(10, Math.max(0, Math.round(progress * 10)));

export const City: FC<{ rider: number | null; youLabel: string }> = ({ rider, youLabel }) => (
  <div class="city" aria-hidden="true">
    <div class="persp">
      <div class="ground">
        <i class="road r1 h" />
        <i class="road r2 h" />
        <i class="road r1 v" />
        <i class="road r2 v" />
        <i class="water" />
        {rider === null ? null : (
          <svg width="360" height="360" viewBox="0 0 360 360">
            <path d={ROUTE} class="halo" />
            <path d={ROUTE} class="line" />
          </svg>
        )}
        <span class="you">
          <span class="bill">
            <span class="tag">{youLabel}</span>
            <span class="stem" />
          </span>
        </span>
        {rider === null ? null : (
          <span class={`rider s${rider}`}>
            <span class="glow" />
            <span class="bill">
              <span class="puck">
                <svg width="15" height="15" viewBox="0 0 24 24">
                  <path d="M3 11l18-8-8 18-2-8z" />
                </svg>
              </span>
              <span class="stem" />
            </span>
          </span>
        )}
        {BUILDINGS.map(([, , , , , lit], i) => (
          <div class={`bd b${i}${lit ? ' lit' : ''}`}>
            <i class="f1" />
            <i class="f2" />
            <i class="f3" />
            <i class="f4" />
            <i class="f5" />
          </div>
        ))}
      </div>
    </div>
    <span class="vignette" />
    <span class="fade" />
  </div>
);

/** Couleurs du plateau, faces des immeubles, et une règle par immeuble et par cran du trajet. */
export const CITY_CSS = `
:root{--map-bg:#EFE8DE;--map-rgb:239,232,222;--ground:#E7DED2;--road1:#FFFFFF;--road2:#FBF7F1;--water:#BCD7E4;--b1:#E6D9CA;--b2:#DCCDBC;--b3:#EFE4D7;--b4:#D6C6B4;--b5:#FFFFFF;--fg-rgb:22,18,14;--bg-rgb:246,242,236}
@media (prefers-color-scheme:dark){:root{--map-bg:#0D0E13;--map-rgb:13,14,19;--ground:#111219;--road1:#252833;--road2:#1E2029;--water:#0F1922;--b1:#1B1D25;--b2:#15161D;--b3:#20222C;--b4:#17181F;--b5:#272A35;--fg-rgb:255,255,255;--bg-rgb:10,10,15}}
@keyframes orbit{0%,100%{transform:rotateX(55deg) rotateZ(-35deg)}50%{transform:rotateX(55deg) rotateZ(-27deg)}}
@keyframes ping{0%{transform:scale(.5);opacity:.8}100%{transform:scale(2.4);opacity:0}}
.city{position:relative;height:380px;overflow:hidden;background:var(--map-bg)}
.persp{position:absolute;inset:0;perspective:820px;perspective-origin:50% 10%}
.ground{position:absolute;left:calc(50% - 180px);top:0;width:360px;height:360px;background:var(--ground);transform-style:preserve-3d;transform:rotateX(55deg) rotateZ(-35deg);animation:orbit 30s ease-in-out infinite}
.ground i,.ground svg{position:absolute;display:block}
.ground svg{left:0;top:0}
.road.h{left:0;width:360px}.road.v{top:0;height:360px}
.road.r1{background:var(--road1)}.road.r2{background:var(--road2)}
.road.r1.h{top:120px;height:16px}.road.r2.h{top:250px;height:12px}
.road.r1.v{left:130px;width:16px}.road.r2.v{left:270px;width:12px}
.water{left:0;top:318px;width:360px;height:42px;background:var(--water)}
.halo,.line{fill:none;stroke-linecap:round;stroke-linejoin:round}
.halo{stroke:rgba(255,106,0,.28);stroke-width:12}.line{stroke:#FF6A00;stroke-width:4.5}
.you,.rider{position:absolute;width:0;height:0;transform-style:preserve-3d}
.you{left:330px;top:256px}
.rider{left:0;top:0;offset-path:path("${ROUTE}");offset-rotate:0deg}
${Array.from({ length: 11 }, (_, i) => `.rider.s${i}{offset-distance:${i * 10}%}`).join('')}
.bill{position:absolute;left:0;top:0;display:flex;flex-direction:column;align-items:center;transform-origin:0 0;transform:rotateZ(35deg) rotateX(-55deg) translate(-50%,-100%)}
.tag{padding:5px 9px;border-radius:10px;background:var(--grad);border:1px solid #FFB000;font-size:11px;font-weight:800;color:#140800;white-space:nowrap}
.stem{width:2px;height:14px;background:rgba(var(--fg-rgb),.55)}
.you .stem{height:46px}
.rider .stem{height:34px;background:rgba(255,177,92,.85)}
.glow{position:absolute;left:-18px;top:-18px;width:36px;height:36px;border-radius:50%;background:radial-gradient(circle,rgba(255,106,0,.6) 0%,rgba(255,106,0,0) 70%);animation:ping 2.4s ease-out infinite}
.puck{width:30px;height:30px;border-radius:50%;background:var(--grad);border:3px solid var(--bg);box-shadow:0 0 18px rgba(255,106,0,.75);display:flex;align-items:center;justify-content:center}
.puck svg{fill:#140800}
.bd{position:absolute;transform-style:preserve-3d}
.bd i{position:absolute;transform-origin:0 0}
.bd .f1{left:0;top:100%;width:100%;height:var(--h);background:var(--b1);transform:rotateX(90deg)}
.bd .f2{left:0;top:0;width:100%;height:var(--h);background:var(--b2);transform:rotateX(90deg)}
.bd .f3{left:100%;top:0;width:var(--h);height:100%;background:var(--b3);transform:rotateY(-90deg)}
.bd .f4{left:0;top:0;width:var(--h);height:100%;background:var(--b4);transform:rotateY(-90deg)}
.bd .f5{inset:0;background:var(--b5);border:1px solid rgba(var(--fg-rgb),.05);transform:translateZ(var(--h))}
.bd.lit .f1,.bd.lit .f3{background-image:repeating-linear-gradient(0deg,rgba(255,177,92,0) 0 7px,rgba(255,177,92,.16) 7px 9px)}
${BUILDINGS.map(([l, t, w, d, h], i) => `.b${i}{left:${l}px;top:${t}px;width:${w}px;height:${d}px;--h:${h}px}`).join('')}
.vignette,.fade{position:absolute;pointer-events:none}
.vignette{inset:0;background:radial-gradient(ellipse at 50% 35%,rgba(var(--map-rgb),0) 50%,rgba(var(--map-rgb),.85) 100%)}
.fade{left:0;right:0;bottom:0;height:140px;background:linear-gradient(180deg,rgba(var(--bg-rgb),0) 0%,var(--bg) 100%)}
@media (prefers-reduced-motion:reduce){.ground,.glow{animation:none}}
`;
