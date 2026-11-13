import 'server-only';

/** Réglages du serveur du back-office (variables d'environnement, voir .env.example). */
export const config = {
  apiUrl: (process.env['TARA_API_URL'] ?? 'http://localhost:3000').replace(/\/$/, ''),
  get sessionSecret(): string {
    const secret = process.env['SESSION_SECRET'];
    if (!secret || secret.length < 32) {
      throw new Error('SESSION_SECRET manquant ou trop court (32 caractères au moins)');
    }
    return secret;
  },
  secureCookies: process.env['NODE_ENV'] === 'production',
};
