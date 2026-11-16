import { z } from 'zod';

/** Code secret : 4 chiffres, comme Orange Money. */
export const PinCode = z.string().regex(/^\d{4}$/, 'quatre chiffres attendus');

/** Clé libérée par l'empreinte digitale (ou le visage) sur ce téléphone. */
export const BiometricKey = z.string().min(40).max(100);

/**
 * Preuve du code secret, jointe aux actions sensibles (retrait, suppression du compte) : le
 * code tapé, ou la clé libérée par l'empreinte sur ce téléphone.
 */
export const PinProofFields = {
  pin: PinCode.optional(),
  biometricKey: BiometricKey.optional(),
};
export const PinProofBody = z.object(PinProofFields);
/** Même preuve, corps facultatif (route qui n'en avait pas). */
export const OptionalPinProofBody = PinProofBody.optional().transform((body) => body ?? {});
export type PinProof = z.output<typeof PinProofBody>;

export const PinStatusDto = z
  .object({
    /** Code secret choisi. */
    set: z.boolean(),
    /** Bloqué après 5 erreurs : choisir un nouveau code avec un code reçu par SMS ou WhatsApp. */
    locked: z.boolean(),
    /** Essais restants avant blocage. */
    remainingAttempts: z.int(),
  })
  .meta({ id: 'PinStatus' });

export const SetPinBody = z
  .object({
    pin: PinCode,
    /** Changement : code actuel… */
    currentPin: PinCode.optional(),
    /** … ou code oublié : code reçu par SMS ou WhatsApp (`POST /me/pin/code`). */
    challengeId: z.uuid().optional(),
    code: z
      .string()
      .regex(/^\d{6}$/)
      .optional(),
  })
  .refine((body) => (body.challengeId === undefined) === (body.code === undefined), {
    message: 'challengeId et code vont ensemble',
    path: ['code'],
  });

export const EnableBiometricBody = z.object({
  pin: PinCode,
  /** Installation de l'app sur ce téléphone : une clé par téléphone. */
  installationId: z.string().min(8).max(64),
});

export const BiometricKeyDto = z
  .object({
    /** À garder dans le stockage chiffré du téléphone, libéré par l'empreinte. */
    key: BiometricKey,
  })
  .meta({ id: 'BiometricKey' });

export const DisableBiometricQuery = z.object({ installationId: z.string().min(8).max(64) });
