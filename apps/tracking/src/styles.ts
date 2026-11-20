import { CITY_CSS } from './views/city.js';

/**
 * Feuille de style de la page (inline : une seule requête). Couleurs et rayons des apps
 * (tara_colors) ; thème sombre selon le téléphone ; police de la marque en deux graisses.
 */
export const CSS =
  `
@font-face{font-family:Jakarta;font-weight:500;font-display:swap;src:url(/static/jakarta-500.woff) format("woff")}
@font-face{font-family:Jakarta;font-weight:800;font-display:swap;src:url(/static/jakarta-800.woff) format("woff")}
:root{color-scheme:light dark;--bg:#F6F2EC;--card:#FFFFFF;--line:rgba(22,18,14,.09);--text:#16120E;--muted:rgba(22,18,14,.68);--faint:rgba(22,18,14,.46);--track:rgba(22,18,14,.1);--accent:#C2410C;--accent-bg:rgba(255,106,0,.08);--accent-line:rgba(255,106,0,.28);--ok:#0E7F57;--ok-bg:rgba(18,128,90,.1);--danger:#C9302C;--danger-bg:rgba(201,48,44,.08);--grad:linear-gradient(100deg,#FFB000,#FF6A00 55%,#FF3D00);--on-brand:#140800;--shadow:0 12px 32px -18px rgba(90,45,0,.35);--sheet:#FFFFFF;--glass:rgba(255,255,255,.84);--glass-line:#FFFFFF;--glass-shadow:0 12px 28px rgba(140,70,10,.08);--soft:rgba(22,18,14,.62);--panel:rgba(255,255,255,.92)}
@media (prefers-color-scheme:dark){:root{--bg:#0A0A0F;--card:#15151C;--line:rgba(255,255,255,.09);--text:#FFFFFF;--muted:rgba(255,255,255,.72);--faint:rgba(255,255,255,.5);--track:rgba(255,255,255,.13);--accent:#FFB15C;--accent-bg:rgba(255,106,0,.12);--accent-line:rgba(255,106,0,.35);--ok:#4ADE9B;--ok-bg:rgba(61,214,140,.12);--danger:#FF7A72;--danger-bg:rgba(255,107,107,.12);--shadow:none;--sheet:#16161E;--glass:rgba(255,255,255,.06);--glass-line:rgba(255,255,255,.1);--glass-shadow:none;--soft:rgba(255,255,255,.62);--panel:rgba(22,22,30,.92)}}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--text);font:500 15px/1.45 Jakarta,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:480px;margin:0 auto;padding:14px 16px 28px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:4px 2px 2px}
.brand{display:block;line-height:0}
.brand img{display:block;height:48px;width:auto}
.ref{font-weight:800;font-size:13px;padding:7px 11px;border-radius:999px;background:var(--card);border:1px solid var(--line)}
.card{background:var(--card);border:1px solid var(--line);border-radius:22px;padding:16px;margin-top:12px;box-shadow:var(--shadow)}
.hero{display:flex;gap:14px;align-items:flex-start}
.badge{flex:none;width:48px;height:48px;border-radius:50%;display:grid;place-items:center;background:var(--grad);color:var(--on-brand)}
.badge.ok{background:var(--ok);color:#fff}.badge.danger{background:var(--danger);color:#fff}.badge.muted{background:var(--track);color:var(--muted)}
.from{color:var(--muted);font-size:13px;margin:0}
h1{font-weight:800;font-size:23px;line-height:1.2;letter-spacing:-.01em;margin:2px 0 4px}
.sub{color:var(--muted);margin:0}
.eta{font-weight:800;color:var(--accent);margin:2px 0 0}
.bar{display:block;width:100%;height:40px;margin-top:12px}
.ends{display:flex;justify-content:space-between;font-size:12px;color:var(--faint);margin-top:2px}
.steps{display:grid;grid-template-columns:repeat(4,1fr);list-style:none;margin:16px 0 0;padding:0}
.steps li{position:relative;text-align:center;font-size:12px;color:var(--faint);font-weight:500}
.steps li::before{content:"";position:absolute;top:6px;left:-50%;width:100%;height:3px;background:var(--track)}
.steps li:first-child::before{display:none}
.steps li.done::before{background:#FF6A00}
.steps .dot{position:relative;display:block;width:15px;height:15px;margin:0 auto 6px;border-radius:50%;background:var(--track)}
.steps li.done{color:var(--text);font-weight:800}.steps li.done .dot{background:var(--grad)}
.steps li.fail{color:var(--danger);font-weight:800}.steps li.fail .dot{background:var(--danger)}
.steps time{display:block;font-weight:500;color:var(--faint);font-variant-numeric:tabular-nums}
.row{display:flex;align-items:center;gap:12px}
.grow{flex:1;min-width:0}
.avatar{flex:none;width:46px;height:46px;border-radius:50%;display:grid;place-items:center;background:var(--grad);color:var(--on-brand);font-weight:800}
.name{font-weight:800;margin:0}
.small{font-size:13px;color:var(--muted);margin:0}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:48px;padding:0 18px;border-radius:16px;border:0;font:800 15px/1 Jakarta,system-ui,sans-serif;text-decoration:none;cursor:pointer}
.btn.primary{background:var(--grad);color:var(--on-brand)}
.btn.ghost{background:transparent;color:var(--text);border:1px solid var(--line)}
.btn.block{width:100%}
.label{font-size:13px;color:var(--muted);margin:0}
.amount{font-weight:800;font-size:30px;letter-spacing:-.01em;margin:2px 0 8px;font-variant-numeric:tabular-nums}
.line{display:flex;justify-content:space-between;color:var(--muted);font-size:14px;padding:3px 0;font-variant-numeric:tabular-nums}
.note{margin:12px 0 0;padding:12px 14px;border-radius:16px;background:var(--accent-bg);border:1px solid var(--accent-line);font-size:14px}
.note.ok{background:var(--ok-bg);border-color:transparent;color:var(--ok);font-weight:800}
.tile{flex:none;width:42px;height:42px;border-radius:14px;display:grid;place-items:center;background:var(--accent-bg);color:var(--accent)}
form{margin:0}
textarea{display:block;width:100%;min-height:64px;margin:12px 0;padding:10px 12px;border-radius:14px;border:1px solid var(--line);background:transparent;color:var(--text);font:inherit;resize:vertical}
.choices{display:grid;gap:8px}
h2{font-weight:800;font-size:17px;margin:0}
.num{flex:none;width:28px;height:28px;border-radius:50%;display:grid;place-items:center;background:var(--accent-bg);color:var(--accent);font-weight:800;font-size:14px}
.step{margin:8px 0 12px}
.field{display:block;font-size:13px;font-weight:800;color:var(--muted);margin-top:12px}
.field+textarea{margin-top:6px}
input[type=text],input[type=tel]{display:block;width:100%;min-height:48px;margin:6px 0 0;padding:10px 12px;border-radius:14px;border:1px solid var(--line);background:transparent;color:var(--text);font:inherit}
.status{margin:10px 0 0;font-size:14px;color:var(--muted)}.status:empty{display:none}
.status.ok{color:var(--ok);font-weight:800}.status.warn{color:var(--accent);font-weight:800}.status.err{color:var(--danger);font-weight:800}
.note.error{background:var(--danger-bg);border-color:transparent;color:var(--danger);font-weight:800}
.btn[disabled]{opacity:.45;cursor:not-allowed}
.center{text-align:center}
[hidden]{display:none!important}
footer{margin-top:22px;text-align:center;color:var(--faint);font-size:12px}
footer p{margin:4px 0}footer a{color:inherit}
:focus-visible{outline:3px solid #FF8A3D;outline-offset:2px}
.wrap.map{padding:0}
.top{position:relative}
header.over{position:absolute;left:0;right:0;top:0;padding:16px 20px 0;display:flex;align-items:center;gap:10px}
.tile-logo{flex:none;padding:6px 8px;border-radius:12px;background:#16120E;display:flex}
.tile-logo img{display:block;width:40px;height:28px;object-fit:contain}
.brandline{display:flex;flex-direction:column;line-height:1.3}
.brandline b{font-size:14px;font-weight:800}.brandline span{font-size:11px;color:var(--soft)}
.secure{flex:none;padding:5px 9px;border-radius:999px;background:var(--glass);border:1px solid var(--glass-line);font-size:11px;font-weight:800;display:flex;align-items:center;gap:5px}
.secure svg{fill:none;stroke:var(--ok);stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}
.sheet{position:relative;margin-top:-50px;padding:16px 20px 20px;border-radius:28px 28px 0 0;background:var(--sheet);box-shadow:0 -16px 40px rgba(0,0,0,.2);min-height:calc(100vh - 330px)}
.sheet main{display:flex;flex-direction:column;gap:12px}
.sheet .card{margin-top:0;padding:12px 14px;background:var(--glass);border-color:var(--glass-line);box-shadow:var(--glass-shadow);-webkit-backdrop-filter:blur(18px) saturate(140%);backdrop-filter:blur(18px) saturate(140%)}
.lead{display:flex;flex-direction:column;gap:12px}
.lead p{margin:0}
.kicker{font-size:12px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;color:var(--accent)}
.headline{display:flex;align-items:center;gap:12px}
.headline h1{flex:1;margin:0;font-size:21px}
.chip{flex:none;padding:8px 10px;border-radius:12px;background:rgba(255,177,92,.14);font-size:14px;font-weight:800;color:var(--accent);font-variant-numeric:tabular-nums}
.lead .sub,.lead .small{margin-top:-6px}
.progress{display:flex;flex-direction:column;gap:6px}
.rail{display:block;height:6px;border-radius:3px;background:var(--track);overflow:hidden}
@keyframes flow{from{background-position:0 0}to{background-position:-200% 0}}
.flow{display:block;height:6px;border-radius:3px;background:linear-gradient(90deg,#FFB000,#FF6A00,#FF3D00,#FF6A00,#FFB000);background-size:200% 100%;animation:flow 2.6s linear infinite}
.flow.k0{width:12%}.flow.k1{width:38%}.flow.k2{width:72%}.flow.k3{width:100%}
.progress.fail .flow{background:var(--danger);animation:none}
.progress ol{display:flex;justify-content:space-between;list-style:none;margin:0;padding:0}
.progress li{font-size:11px;font-weight:800;color:var(--faint)}
.progress li.on{color:var(--accent)}
.progress.fail li.on:last-child{color:var(--danger)}
.note-card{font-size:13px;line-height:1.45;color:var(--muted)}
.pay .row{gap:10px}
.pay .name{font-size:13px}.pay .small{font-size:12px;color:var(--soft)}
.op{flex:none;width:26px;height:26px;border-radius:7px;background:#FFF;box-shadow:0 0 0 1px rgba(22,18,14,.08)}
.pay .amount{font-size:18px;margin:0 0 0 6px;white-space:nowrap}
.split{margin-top:8px;padding-top:6px;border-top:1px solid var(--line)}
.pay .fee{margin-top:6px}
.actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:4px}
.actions.one{grid-template-columns:1fr}
.actions .btn{min-height:50px;font-size:14px}
.btn.call{background:rgba(74,222,155,.14);color:var(--ok)}
.btn.glass{background:var(--glass);border:1px solid var(--glass-line);box-shadow:var(--glass-shadow);color:var(--text)}
.btn.glass svg{color:var(--accent)}
.sheet .note{margin:0}
.sheet footer{margin-top:18px}
@media (prefers-reduced-motion:reduce){.flow{animation:none}}
.bubble{position:absolute;left:20px;right:20px;top:80px;margin:0;padding:10px 12px;border-radius:14px;background:var(--panel);font-size:13px;line-height:1.45}
.locate{position:absolute;right:20px;top:330px;min-height:44px;padding:0 12px;border-radius:14px;border:0;background:var(--sheet);color:var(--text);font:800 12px/1 Jakarta,system-ui,sans-serif;display:flex;align-items:center;gap:6px;box-shadow:0 8px 20px rgba(0,0,0,.15);cursor:pointer}
.locate svg{fill:none;stroke:var(--accent);stroke-width:2;stroke-linecap:round}
.locate[disabled]{opacity:.6}
#place{display:flex;flex-direction:column;gap:10px}
.pt{font-size:15px;margin:0}
#place .status{margin:-4px 0 0;font-size:13px}
.boxed{display:flex;flex-direction:column;justify-content:center;min-height:56px;padding:8px 14px;border-radius:16px;background:var(--glass);border:1px solid rgba(var(--fg-rgb),.14)}
.boxed span{font-size:11px;font-weight:800;color:var(--soft)}
.boxed textarea{margin:2px 0 0;padding:0;min-height:0;border:0;border-radius:0;background:transparent;font-weight:800;font-size:16px;resize:none}
.boxed textarea:focus{outline:none}.boxed:focus-within{outline:3px solid #FF8A3D;outline-offset:2px}
.more{border-radius:16px;border:1.5px dashed rgba(255,177,92,.6);padding:12px 14px}
.more summary{font-size:12px;font-weight:800;cursor:pointer}
.btn.big{height:56px;border-radius:20px;font-size:16px}
#place .small.center{margin:0}
.done{display:flex;flex-direction:column;align-items:center;gap:8px;padding:8px 0;text-align:center;animation:rise .4s ease-out both}
@keyframes rise{0%{transform:translateY(14px);opacity:0}100%{transform:none;opacity:1}}
.done h1{font-size:17px;margin:0}.done p{margin:0;font-size:13px;color:var(--muted)}
.orb{position:relative;width:70px;height:70px;border-radius:50%;overflow:hidden;display:grid;place-items:center;background:rgba(74,222,155,.14);color:#FFF}
.done.muted .orb{background:var(--track);color:var(--text)}
.orb .fill{position:absolute;left:-35px;top:28px;width:140px;height:140px;border-radius:42%;background:linear-gradient(180deg,#7CF0B8,#2CC28A 55%,#0E7F57);animation:swirl 6s linear infinite}
.done.muted .fill{display:none}
@keyframes swirl{to{transform:rotate(360deg)}}
.orb svg{position:relative;stroke-width:3}
@media (prefers-reduced-motion:reduce){.done,.orb .fill{animation:none}}
` + CITY_CSS;
