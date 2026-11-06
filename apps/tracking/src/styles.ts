/**
 * Feuille de style de la page (inline : une seule requête). Couleurs et rayons des apps
 * (tara_colors) ; thème sombre selon le téléphone ; police de la marque en deux graisses.
 */
export const CSS = `
@font-face{font-family:Jakarta;font-weight:500;font-display:swap;src:url(/static/jakarta-500.woff) format("woff")}
@font-face{font-family:Jakarta;font-weight:800;font-display:swap;src:url(/static/jakarta-800.woff) format("woff")}
:root{color-scheme:light dark;--bg:#F6F2EC;--card:#FFFFFF;--line:rgba(22,18,14,.09);--text:#16120E;--muted:rgba(22,18,14,.68);--faint:rgba(22,18,14,.46);--track:rgba(22,18,14,.1);--accent:#C24A00;--accent-bg:rgba(255,106,0,.08);--accent-line:rgba(255,106,0,.28);--ok:#12805A;--ok-bg:rgba(18,128,90,.1);--danger:#C9302C;--danger-bg:rgba(201,48,44,.08);--grad:linear-gradient(100deg,#FFB000,#FF6A00 55%,#FF3D00);--on-brand:#140800;--shadow:0 12px 32px -18px rgba(90,45,0,.35)}
@media (prefers-color-scheme:dark){:root{--bg:#0A0A0F;--card:#15151C;--line:rgba(255,255,255,.09);--text:#FFFFFF;--muted:rgba(255,255,255,.72);--faint:rgba(255,255,255,.5);--track:rgba(255,255,255,.13);--accent:#FF9A4D;--accent-bg:rgba(255,106,0,.12);--accent-line:rgba(255,106,0,.35);--ok:#3DD68C;--ok-bg:rgba(61,214,140,.12);--danger:#FF7A72;--danger-bg:rgba(255,107,107,.12);--shadow:none}}
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
`;
