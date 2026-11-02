import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Limitation de débit par compte plutôt que par adresse IP quand l'utilisateur est connecté.
 * Au Cameroun, les opérateurs mobiles font partager une même adresse IP publique à de
 * nombreux abonnés (CGNAT) : une limite par IP pénaliserait des clients légitimes.
 * Cette garde s'exécute APRÈS AuthGuard, qui renseigne `request.user`.
 */
@Injectable()
export class UserAwareThrottlerGuard extends ThrottlerGuard {
  protected override getTracker(request: Record<string, unknown>): Promise<string> {
    const user = request['user'] as { id?: string } | undefined;
    if (user?.id) return Promise.resolve(`user:${user.id}`);
    const ip = typeof request['ip'] === 'string' ? request['ip'] : 'inconnue';
    return Promise.resolve(`ip:${ip}`);
  }
}
