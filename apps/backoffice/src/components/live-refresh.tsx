'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

/**
 * Relit la page toutes les [seconds] secondes tant que l'onglet est affiché : une réponse
 * de l'expéditeur ou du livreur apparaît sans recharger. Le texte en cours de saisie est
 * gardé (seules les données du serveur sont relues).
 */
export function LiveRefresh({ seconds = 4 }: { seconds?: number }) {
  const router = useRouter();
  useEffect(() => {
    const timer = setInterval(() => {
      if (document.visibilityState === 'visible') router.refresh();
    }, seconds * 1000);
    const onVisible = () => {
      if (document.visibilityState === 'visible') router.refresh();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [router, seconds]);
  return null;
}
