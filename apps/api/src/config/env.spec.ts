import { InvalidEnvironmentError, parseEnv } from './env.js';

describe('parseEnv', () => {
  const valid = { DATABASE_URL: 'postgresql://tara:tara@localhost:5432/tara' };

  it('applique les valeurs par défaut', () => {
    expect(parseEnv(valid)).toMatchObject({ NODE_ENV: 'development', PORT: 3000 });
  });

  it('convertit le port en nombre', () => {
    expect(parseEnv({ ...valid, PORT: '8080' }).PORT).toBe(8080);
  });

  it('refuse une configuration sans base de données', () => {
    expect(() => parseEnv({})).toThrow(InvalidEnvironmentError);
  });

  it('refuse une URL de base qui n’est pas PostgreSQL', () => {
    expect(() => parseEnv({ DATABASE_URL: 'mysql://localhost/tara' })).toThrow(/DATABASE_URL/);
  });
});
