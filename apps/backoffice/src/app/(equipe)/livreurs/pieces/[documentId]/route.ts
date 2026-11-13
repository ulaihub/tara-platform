import { NextResponse } from 'next/server';
import { config } from '@/lib/config';
import { requireStaff } from '@/lib/dal';
import { RIDER_ROLES } from '@/lib/riders';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Types acceptés pour une pièce (comme à l'envoi) ; tout autre contenu est refusé. */
const IMAGES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const PDF = 'application/pdf';

/**
 * Pièce d'un livreur, ouverte dans un nouvel onglet pour l'examiner. Le fichier passe par le
 * serveur du back-office (le jeton ne quitte jamais le serveur) ; l'API trace chaque
 * consultation. Une image s'affiche dans une page isolée (aucun script, aucun cache) ; un
 * PDF est téléchargé.
 */
export async function GET(_: Request, { params }: { params: Promise<{ documentId: string }> }) {
  const session = await requireStaff(RIDER_ROLES);
  const { documentId } = await params;
  if (!UUID.test(documentId)) {
    return NextResponse.json({ error: 'Pièce inconnue.' }, { status: 400 });
  }
  let upstream: Response;
  try {
    upstream = await fetch(`${config.apiUrl}/v1/admin/kyc-documents/${documentId}/file`, {
      headers: { authorization: `Bearer ${session.accessToken}` },
      cache: 'no-store',
      signal: AbortSignal.timeout(15_000),
    });
  } catch {
    return NextResponse.json({ error: 'L’API Tara ne répond pas.' }, { status: 502 });
  }
  if (!upstream.ok) {
    return NextResponse.json(
      { error: upstream.status === 404 ? 'Pièce introuvable.' : 'Pièce indisponible.' },
      { status: upstream.status === 404 ? 404 : 502 },
    );
  }
  const type = (upstream.headers.get('content-type') ?? '').split(';')[0]?.trim().toLowerCase();
  if (!type || (!IMAGES.has(type) && type !== PDF)) {
    return NextResponse.json({ error: 'Type de fichier refusé.' }, { status: 415 });
  }
  const extension = type === PDF ? 'pdf' : type.split('/')[1];
  return new NextResponse(await upstream.arrayBuffer(), {
    headers: {
      'content-type': type,
      'content-disposition': `${type === PDF ? 'attachment' : 'inline'}; filename="piece-${documentId.slice(0, 8)}.${extension}"`,
      'cache-control': 'no-store, private',
      'x-content-type-options': 'nosniff',
      'content-security-policy':
        "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox",
      'referrer-policy': 'no-referrer',
    },
  });
}
