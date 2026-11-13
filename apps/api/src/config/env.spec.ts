import { InvalidEnvironmentError, parseEnv, smsTestNumbers } from './env.js';

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

  it('lit les téléphones de test et refuse une liste invalide ou trop longue', () => {
    const env = parseEnv({ ...valid, SMS_TEST_NUMBERS: ' 640 11 40 64, +237677123456 ,,' });
    expect([...smsTestNumbers(env)]).toEqual(['+237640114064', '+237677123456']);
    expect(smsTestNumbers(parseEnv(valid)).size).toBe(0);
    expect(() => parseEnv({ ...valid, SMS_TEST_NUMBERS: '+237640114064,12345' })).toThrow(
      /SMS_TEST_NUMBERS/,
    );
    const many = Array.from({ length: 21 }, (_, i) => `+2376770000${String(i).padStart(2, '0')}`);
    expect(() => parseEnv({ ...valid, SMS_TEST_NUMBERS: many.join(',') })).toThrow(
      /SMS_TEST_NUMBERS : 20 numéros de test au plus/,
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

  it('exige le compartiment et les clés du stockage S3', () => {
    expect(() => parseEnv({ ...valid, STORAGE_DRIVER: 's3' })).toThrow(
      /S3_BUCKET[\s\S]*S3_ACCESS_KEY_ID[\s\S]*S3_SECRET_ACCESS_KEY/,
    );
    const env = parseEnv({
      ...valid,
      STORAGE_DRIVER: 's3',
      S3_ENDPOINT: 'https://s3.example.cm',
      S3_BUCKET: 'tara-fichiers',
      S3_ACCESS_KEY_ID: 'cle',
      S3_SECRET_ACCESS_KEY: 'secret',
      S3_FORCE_PATH_STYLE: 'false',
    });
    expect(env).toMatchObject({ STORAGE_DRIVER: 's3', S3_FORCE_PATH_STYLE: false });
  });

  it('refuse la même clé de stockage en actuelle et en ancienne', () => {
    expect(() =>
      parseEnv({ ...valid, STORAGE_ENCRYPTION_KEY_PREVIOUS: valid.STORAGE_ENCRYPTION_KEY }),
    ).toThrow(/STORAGE_ENCRYPTION_KEY_PREVIOUS/);
  });

  it('interdit le SMS factice et le stockage local en production', () => {
    expect(() => parseEnv({ ...valid, NODE_ENV: 'production' })).toThrow(
      /SMS_PROVIDER[\s\S]*PUSH_PROVIDER[\s\S]*PAYMENT_PROVIDER[\s\S]*STORAGE_DRIVER/,
    );
  });
});
