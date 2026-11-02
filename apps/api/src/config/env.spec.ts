import { InvalidEnvironmentError, parseEnv } from './env.js';

describe('parseEnv', () => {
  const valid = {
    DATABASE_URL: 'postgresql://tara:tara@localhost:5432/tara',
    REDIS_URL: 'redis://localhost:6379',
    JWT_SECRET: 'x'.repeat(32),
    CODE_HASH_SECRET: 'y'.repeat(32),
    STORAGE_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64'),
  };

  it('applique les valeurs par défaut', () => {
    expect(parseEnv(valid)).toMatchObject({
      NODE_ENV: 'development',
      PORT: 3000,
      DEFAULT_CITY: 'Douala',
      SMS_PROVIDER: 'fake',
      JOBS_ENABLED: true,
    });
  });

  it('convertit les nombres et les booléens', () => {
    const env = parseEnv({ ...valid, PORT: '8080', JOBS_ENABLED: 'false' });
    expect(env.PORT).toBe(8080);
    expect(env.JOBS_ENABLED).toBe(false);
  });

  it('refuse une configuration sans base de données', () => {
    expect(() => parseEnv({})).toThrow(InvalidEnvironmentError);
  });

  it('refuse une URL de base qui n’est pas PostgreSQL', () => {
    expect(() => parseEnv({ ...valid, DATABASE_URL: 'mysql://localhost/tara' })).toThrow(
      /DATABASE_URL/,
    );
  });

  it('exige les identifiants du fournisseur SMS choisi et un secours distinct', () => {
    expect(() => parseEnv({ ...valid, SMS_PROVIDER: 'orange' })).toThrow(
      /ORANGE_SMS_CLIENT_ID[\s\S]*ORANGE_SMS_SENDER_PHONE/,
    );
    const orange = {
      ...valid,
      SMS_PROVIDER: 'orange',
      ORANGE_SMS_CLIENT_ID: 'client-orange',
      ORANGE_SMS_CLIENT_SECRET: 'secret-orange',
      ORANGE_SMS_SENDER_PHONE: '+237690000000',
    };
    expect(parseEnv(orange).SMS_FALLBACK_PROVIDER).toBe('none');
    expect(() => parseEnv({ ...orange, SMS_FALLBACK_PROVIDER: 'orange' })).toThrow(
      /SMS_FALLBACK_PROVIDER/,
    );
    expect(() => parseEnv({ ...orange, SMS_FALLBACK_PROVIDER: 'twilio' })).toThrow(
      /TWILIO_ACCOUNT_SID/,
    );
  });

  it('refuse un secret JWT trop court', () => {
    expect(() => parseEnv({ ...valid, JWT_SECRET: 'court' })).toThrow(/JWT_SECRET/);
  });

  it('refuse une clé de chiffrement qui ne fait pas 32 octets', () => {
    expect(() =>
      parseEnv({ ...valid, STORAGE_ENCRYPTION_KEY: Buffer.alloc(16).toString('base64') }),
    ).toThrow(/STORAGE_ENCRYPTION_KEY/);
  });

  it('interdit le SMS factice et le stockage local en production', () => {
    expect(() => parseEnv({ ...valid, NODE_ENV: 'production' })).toThrow(
      /SMS_PROVIDER[\s\S]*PUSH_PROVIDER[\s\S]*PAYMENT_PROVIDER[\s\S]*STORAGE_DRIVER/,
    );
  });
});
