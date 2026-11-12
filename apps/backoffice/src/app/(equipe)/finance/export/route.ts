import { NextResponse, type NextRequest } from 'next/server';
import { config } from '@/lib/config';
import { requireStaff } from '@/lib/dal';
import { FINANCE_ROLES, exportRange } from '@/lib/finance';

/**
 * Export comptable du journal (CSV, séparateur point-virgule) pour une période. Le fichier
 * passe par le serveur du back-office : le jeton ne quitte jamais le serveur ; l'API trace
 * chaque export au journal d'audit.
 */
export async function GET(request: NextRequest) {
  const session = await requireStaff(FINANCE_ROLES);
  const from = request.nextUrl.searchParams.get('du') ?? '';
  const to = request.nextUrl.searchParams.get('au') ?? '';
  const invalid = exportRange(from, to);
  if (invalid) return NextResponse.json({ error: invalid }, { status: 400 });
  let upstream: Response;
  try {
    upstream = await fetch(`${config.apiUrl}/v1/admin/finance/journal.csv?from=${from}&to=${to}`, {
      headers: { authorization: `Bearer ${session.accessToken}` },
      cache: 'no-store',
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    return NextResponse.json({ error: 'L’API Tara ne répond pas.' }, { status: 502 });
  }
  if (!upstream.ok) {
    return NextResponse.json({ error: 'Export impossible pour cette période.' }, { status: 502 });
  }
  return new NextResponse(upstream.body, {
    headers: {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': `attachment; filename="tara-journal-${from}-${to}.csv"`,
      'cache-control': 'no-store, private',
      'x-content-type-options': 'nosniff',
    },
  });
}
