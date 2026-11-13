import { NextResponse } from 'next/server';
import { config } from '@/lib/config';
import { requireStaff } from '@/lib/dal';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const IMAGES = new Set(['image/jpeg', 'image/png', 'image/webp']);

/** Photo de preuve (`preuve`) ou photo du colis à la commande (`colis`). */
const SOURCES: Record<string, (id: string) => string> = {
  preuve: (id) => `/admin/support/proofs/${id}/photo`,
  colis: (id) => `/admin/support/orders/${id}/parcel-photo`,
};

/**
 * Photo versée à un litige, ouverte dans un nouvel onglet. Le fichier passe par le serveur
 * du back-office (le jeton ne quitte jamais le serveur) ; l'API trace chaque consultation.
 * Seules les images sont acceptées, affichées dans une page isolée, jamais mises en cache.
 */
export async function GET(
  _: Request,
  { params }: { params: Promise<{ kind: string; id: string }> },
) {
  const session = await requireStaff(['ADMIN', 'SUPPORT', 'DISPATCHER']);
  const { kind, id } = await params;
  const source = SOURCES[kind];
  if (!source || !UUID.test(id)) {
    return NextResponse.json({ error: 'Photo inconnue.' }, { status: 400 });
  }
  let upstream: Response;
  try {
    upstream = await fetch(`${config.apiUrl}/v1${source(id)}`, {
      headers: { authorization: `Bearer ${session.accessToken}` },
      cache: 'no-store',
      signal: AbortSignal.timeout(15_000),
    });
  } catch {
    return NextResponse.json({ error: 'L’API Tara ne répond pas.' }, { status: 502 });
  }
  if (!upstream.ok) {
    return NextResponse.json(
      { error: upstream.status === 404 ? 'Photo introuvable.' : 'Photo indisponible.' },
      { status: upstream.status === 404 ? 404 : 502 },
    );
  }
  const type = (upstream.headers.get('content-type') ?? '').split(';')[0]?.trim().toLowerCase();
  if (!type || !IMAGES.has(type)) {
    return NextResponse.json({ error: 'Type de fichier refusé.' }, { status: 415 });
  }
  return new NextResponse(await upstream.arrayBuffer(), {
    headers: {
      'content-type': type,
      'content-disposition': `inline; filename="${kind}-${id.slice(0, 8)}.${type.split('/')[1]}"`,
      'cache-control': 'no-store, private',
      'x-content-type-options': 'nosniff',
      'content-security-policy':
        "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox",
      'referrer-policy': 'no-referrer',
    },
  });
}
