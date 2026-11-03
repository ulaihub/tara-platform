import { ServiceUnavailableException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service.js';
import { HealthController } from './health.controller.js';

describe('HealthController', () => {
  const ping = vi.fn<() => Promise<void>>();
  let controller: HealthController;

  beforeEach(async () => {
    ping.mockReset();
    const moduleRef = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [{ provide: PrismaService, useValue: { ping } }],
    }).compile();
    controller = moduleRef.get(HealthController);
  });

  it('répond ok quand la base répond', async () => {
    ping.mockResolvedValue();
    await expect(controller.check()).resolves.toEqual({
      status: 'ok',
      checks: { database: 'up' },
    });
  });

  it('répond 503 quand la base ne répond pas', async () => {
    ping.mockRejectedValue(new Error('connexion refusée'));
    await expect(controller.check()).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
