import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

/**
 * Vérifie les protections posées en base par la migration `db_guards`.
 * Ces règles protègent l'argent et les preuves même si le code applicatif se trompe.
 */

const pool = new pg.Pool({ connectionString: process.env['DATABASE_URL'] });

const PG_CHECK_VIOLATION = '23514';
const PG_RESTRICT_VIOLATION = '23001';
const PG_INSUFFICIENT_PRIVILEGE = '42501';
/** Refus par le trigger (compte propriétaire) ou par les droits (compte de l'API). */
const APPEND_ONLY = [PG_RESTRICT_VIOLATION, PG_INSUFFICIENT_PRIVILEGE];

async function pgErrorCode(run: () => Promise<unknown>): Promise<string | undefined> {
  try {
    await run();
  } catch (error) {
    return (error as { code?: string }).code;
  }
  return undefined;
}

async function createAccount(label: string): Promise<string> {
  const id = randomUUID();
  await pool.query(
    `INSERT INTO ledger_accounts (id, code, name, type, owner_type)
     VALUES ($1, $2, $3, 'LIABILITY', 'PLATFORM')`,
    [id, `test:${label}:${id}`, `Compte de test ${label}`],
  );
  return id;
}

/** Insère une écriture et ses lignes dans une transaction, puis valide. */
async function postEntry(amounts: Array<[accountId: string, amount: number]>): Promise<string> {
  const client = await pool.connect();
  const entryId = randomUUID();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO journal_entries (id, kind, description, idempotency_key)
       VALUES ($1, 'ADJUSTMENT', 'test', $2)`,
      [entryId, `test:${entryId}`],
    );
    for (const [accountId, amount] of amounts) {
      await client.query(
        `INSERT INTO ledger_postings (id, entry_id, account_id, amount) VALUES ($1, $2, $3, $4)`,
        [randomUUID(), entryId, accountId, amount],
      );
    }
    await client.query('COMMIT');
    return entryId;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

afterAll(async () => {
  await pool.end();
});

describe('grand livre', () => {
  let cash: string;
  let merchantPayable: string;

  beforeAll(async () => {
    cash = await createAccount('cash');
    merchantPayable = await createAccount('merchant');
  });

  it('accepte une écriture équilibrée', async () => {
    const entryId = await postEntry([
      [cash, 15_000],
      [merchantPayable, -15_000],
    ]);
    const { rows } = await pool.query<{ total: string }>(
      'SELECT SUM(amount)::text AS total FROM ledger_postings WHERE entry_id = $1',
      [entryId],
    );
    expect(rows[0]?.total).toBe('0');
  });

  it('refuse une écriture déséquilibrée à la validation de la transaction', async () => {
    const code = await pgErrorCode(() =>
      postEntry([
        [cash, 15_000],
        [merchantPayable, -14_000],
      ]),
    );
    expect(code).toBe(PG_CHECK_VIOLATION);
  });

  it('refuse une écriture à une seule ligne', async () => {
    const code = await pgErrorCode(() => postEntry([[cash, 1_000]]));
    expect(code).toBe(PG_CHECK_VIOLATION);
  });

  it('refuse une écriture sans aucune ligne', async () => {
    const code = await pgErrorCode(() => postEntry([]));
    expect(code).toBe(PG_CHECK_VIOLATION);
  });

  it('refuse une ligne à montant nul', async () => {
    const code = await pgErrorCode(() =>
      postEntry([
        [cash, 0],
        [merchantPayable, 0],
      ]),
    );
    expect(code).toBe(PG_CHECK_VIOLATION);
  });

  it('interdit de modifier ou de supprimer une ligne validée', async () => {
    const entryId = await postEntry([
      [cash, 2_500],
      [merchantPayable, -2_500],
    ]);
    expect(
      await pgErrorCode(() =>
        pool.query('UPDATE ledger_postings SET amount = amount + 1 WHERE entry_id = $1', [entryId]),
      ),
    ).toBeOneOf(APPEND_ONLY);
    expect(
      await pgErrorCode(() =>
        pool.query('DELETE FROM ledger_postings WHERE entry_id = $1', [entryId]),
      ),
    ).toBeOneOf(APPEND_ONLY);
    expect(
      await pgErrorCode(() => pool.query('DELETE FROM journal_entries WHERE id = $1', [entryId])),
    ).toBeOneOf(APPEND_ONLY);
  });
});

describe('compte de l’API', () => {
  it('ne peut pas désactiver les protections du grand livre', async () => {
    const { rows } = await pool.query<{ super: boolean }>(
      'SELECT rolsuper AS super FROM pg_roles WHERE rolname = current_user',
    );
    // En développement, le compte local est administrateur : vérification faite en CI.
    if (rows[0]?.super) return;
    const code = await pgErrorCode(() =>
      pool.query('ALTER TABLE ledger_postings DISABLE TRIGGER ALL'),
    );
    expect(code).toBe(PG_INSUFFICIENT_PRIVILEGE);
    expect(await pgErrorCode(() => pool.query('SELECT * FROM _prisma_migrations LIMIT 1'))).toBe(
      PG_INSUFFICIENT_PRIVILEGE,
    );
  });
});

describe('journal d’audit', () => {
  it('est en ajout seul', async () => {
    const id = randomUUID();
    await pool.query(
      `INSERT INTO audit_logs (id, actor_roles, action, entity_type, entity_id)
       VALUES ($1, '{ADMIN}', 'test.action', 'test', $2)`,
      [id, id],
    );
    expect(
      await pgErrorCode(() =>
        pool.query(`UPDATE audit_logs SET action = 'falsifié' WHERE id = $1`, [id]),
      ),
    ).toBeOneOf(APPEND_ONLY);
  });
});

describe('adresses', () => {
  it('calcule la position PostGIS à partir de la latitude et de la longitude', async () => {
    const id = randomUUID();
    // Carrefour Ancien Dalip, Akwa, Douala (coordonnées approximatives).
    await pool.query(
      `INSERT INTO addresses (id, landmark, latitude, longitude, source, updated_at)
       VALUES ($1, 'En face de la pharmacie du carrefour', 4.0511, 9.7016, 'SENDER', now())`,
      [id],
    );
    const { rows } = await pool.query<{ lat: number; lng: number }>(
      `SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng
         FROM addresses WHERE id = $1`,
      [id],
    );
    expect(rows[0]?.lat).toBeCloseTo(4.0511, 6);
    expect(rows[0]?.lng).toBeCloseTo(9.7016, 6);

    await pool.query('UPDATE addresses SET latitude = 4.0300, longitude = 9.6950 WHERE id = $1', [
      id,
    ]);
    const moved = await pool.query<{ lat: number }>(
      'SELECT ST_Y(location::geometry) AS lat FROM addresses WHERE id = $1',
      [id],
    );
    expect(moved.rows[0]?.lat).toBeCloseTo(4.03, 6);
  });

  it('exige un repère écrit', async () => {
    const code = await pgErrorCode(() =>
      pool.query(
        `INSERT INTO addresses (id, landmark, latitude, longitude, source, updated_at)
         VALUES ($1, '   ', 4.05, 9.70, 'SENDER', now())`,
        [randomUUID()],
      ),
    );
    expect(code).toBe(PG_CHECK_VIOLATION);
  });
});

describe('utilisateurs', () => {
  it('exige un numéro au format international', async () => {
    const insert = (phone: string) =>
      pool.query(`INSERT INTO users (id, phone, updated_at) VALUES ($1, $2, now())`, [
        randomUUID(),
        phone,
      ]);
    const unique = String(Date.now()).slice(-8);
    await expect(insert(`+2376${unique}`)).resolves.toBeDefined();
    expect(await pgErrorCode(() => insert(`6${unique}`))).toBe(PG_CHECK_VIOLATION);
  });
});
