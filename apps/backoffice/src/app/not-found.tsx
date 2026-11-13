import Link from 'next/link';
import { Logo } from '@/components/ui';

/** Adresse inconnue du back-office. */
export default function NotFound() {
  return (
    <main className="grid min-h-screen place-items-center px-6">
      <div className="max-w-sm text-center">
        <div className="mb-8 flex justify-center">
          <Logo />
        </div>
        <h1 className="font-display text-[26px] font-bold">Page introuvable</h1>
        <p className="mt-2 text-muted">Cette adresse ne mène à aucun écran du back-office.</p>
        <Link
          href="/"
          className="mt-6 inline-flex min-h-11 items-center rounded-2xl bg-brand px-5 font-bold text-on-brand"
        >
          Retour à l’accueil
        </Link>
      </div>
    </main>
  );
}
