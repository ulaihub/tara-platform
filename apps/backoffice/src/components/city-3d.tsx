/**
 * Ville en relief des maquettes (BO-Connexion) en HTML et CSS seuls : plateau incliné qui
 * oscille, immeubles en cinq faces, trajet en pointillés qui avance et trois livreurs qui
 * roulent. Décor : masqué aux lecteurs d'écran. Positions dans globals.css (pas de style
 * en ligne : la page l'interdit).
 */
const BUILDINGS = 20;
const LIT = new Set([3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]);

export function City3D() {
  return (
    <div className="bo-city" aria-hidden="true">
      <div className="bo-city-zoom">
        <div className="bo-city-persp">
          <div className="bo-city-ground">
            <i className="road r1 h" />
            <i className="road r2 h" />
            <i className="road r1 v" />
            <i className="road r2 v" />
            <i className="water" />
            <svg width="360" height="360" viewBox="0 0 360 360">
              <path className="halo" d="M20 128 L 138 128 L 138 256 L 276 256 L 276 340" />
              <path className="dash" d="M20 128 L 138 128 L 138 256 L 276 256 L 276 340" />
            </svg>
            {[1, 2, 3].map((n) => (
              <span key={n} className={`rider r${n}`}>
                <span className="glow" />
                <span className="bill">
                  <span className="puck">
                    <svg width="15" height="15" viewBox="0 0 24 24">
                      <path d="M3 11l18-8-8 18-2-8z" />
                    </svg>
                  </span>
                  <span className="stem" />
                </span>
              </span>
            ))}
            {Array.from({ length: BUILDINGS }, (_, i) => (
              <div key={i} className={`bd b${i}${LIT.has(i) ? ' lit' : ''}`}>
                <i className="f1" />
                <i className="f2" />
                <i className="f3" />
                <i className="f4" />
                <i className="f5" />
              </div>
            ))}
          </div>
        </div>
      </div>
      <span className="vignette" />
    </div>
  );
}
