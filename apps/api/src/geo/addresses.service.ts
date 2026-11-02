import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { type AuthUser, isStaff } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import type { Address, Prisma, Zone } from '../generated/prisma/client.js';
import type { AddressSource } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaService } from '../storage/media.service.js';
import type { AddressBody, AddressDto } from './geo.schemas.js';
import { ZonesRepository } from './zones.repository.js';

type AddressWithNeighborhood = Address & { neighborhood: Pick<Zone, 'id' | 'name'> | null };

export interface NewAddress {
  ownerId: string | null;
  source: AddressSource;
  latitude: number;
  longitude: number;
  landmark: string;
  label?: string | undefined;
  contactName?: string | null | undefined;
  contactPhone?: string | null | undefined;
  neighborhoodId?: string | undefined;
  photoKey?: string | undefined;
  voiceNoteKey?: string | undefined;
}

@Injectable()
export class AddressesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly zones: ZonesRepository,
    private readonly media: MediaService,
  ) {}

  toDto(address: AddressWithNeighborhood, restricted: boolean): z.output<typeof AddressDto> {
    return {
      id: address.id,
      label: address.label,
      contactName: address.contactName,
      contactPhone: address.contactPhone,
      city: address.city,
      neighborhood: address.neighborhood
        ? { id: address.neighborhood.id, name: address.neighborhood.name }
        : null,
      landmark: address.landmark,
      latitude: address.latitude,
      longitude: address.longitude,
      photoKey: address.photoKey,
      voiceNoteKey: address.voiceNoteKey,
      source: address.source,
      verifiedAt: address.verifiedAt?.toISOString() ?? null,
      motorbikeRestricted: restricted,
      createdAt: address.createdAt.toISOString(),
    };
  }

  async toDtos(addresses: AddressWithNeighborhood[]): Promise<z.output<typeof AddressDto>[]> {
    const restricted = await this.zones.restrictedAddressIds(addresses.map((a) => a.id));
    return addresses.map((address) => this.toDto(address, restricted.has(address.id)));
  }

  /**
   * Crée une adresse après contrôle de la zone desservie (B6) ; le quartier est déduit
   * du point si l'utilisateur ne l'a pas choisi (B1).
   */
  async createAddress(
    input: NewAddress,
    tx?: Prisma.TransactionClient,
  ): Promise<AddressWithNeighborhood> {
    const serviceAreas = await this.zones.findContaining(
      input.latitude,
      input.longitude,
      'SERVICE_AREA',
    );
    const area = serviceAreas[0];
    if (!area) throw AppError.unprocessable('OUT_OF_SERVICE_AREA');

    let neighborhoodId = input.neighborhoodId ?? null;
    if (neighborhoodId) {
      const zone = await this.prisma.zone.findUnique({ where: { id: neighborhoodId } });
      if (!zone || zone.kind !== 'NEIGHBORHOOD') {
        throw AppError.badRequest('VALIDATION_FAILED', {}, [
          { path: 'neighborhoodId', message: 'quartier inconnu' },
        ]);
      }
    } else {
      const neighborhoods = await this.zones.findContaining(
        input.latitude,
        input.longitude,
        'NEIGHBORHOOD',
      );
      neighborhoodId = neighborhoods[0]?.id ?? null;
    }

    return (tx ?? this.prisma).address.create({
      data: {
        ownerId: input.ownerId,
        source: input.source,
        label: input.label ?? null,
        contactName: input.contactName ?? null,
        contactPhone: input.contactPhone ?? null,
        city: area.city,
        neighborhoodId,
        landmark: input.landmark,
        latitude: input.latitude,
        longitude: input.longitude,
        photoKey: input.photoKey ?? null,
        voiceNoteKey: input.voiceNoteKey ?? null,
      },
      include: { neighborhood: { select: { id: true, name: true } } },
    });
  }

  async create(
    user: AuthUser,
    body: z.output<typeof AddressBody>,
  ): Promise<z.output<typeof AddressDto>> {
    if (body.photoKey) await this.media.assertOwned(user.id, body.photoKey, ['ADDRESS_PHOTO']);
    if (body.voiceNoteKey) await this.media.assertOwned(user.id, body.voiceNoteKey, ['VOICE_NOTE']);
    const address = await this.createAddress({ ...body, ownerId: user.id, source: 'SENDER' });
    const [dto] = await this.toDtos([address]);
    return dto as z.output<typeof AddressDto>;
  }

  /** Carnet d'adresses de l'utilisateur (B5). */
  async list(user: AuthUser): Promise<z.output<typeof AddressDto>[]> {
    const addresses = await this.prisma.address.findMany({
      where: { ownerId: user.id },
      orderBy: { updatedAt: 'desc' },
      take: 100,
      include: { neighborhood: { select: { id: true, name: true } } },
    });
    return this.toDtos(addresses);
  }

  async get(user: AuthUser, id: string): Promise<z.output<typeof AddressDto>> {
    const address = await this.prisma.address.findUnique({
      where: { id },
      include: { neighborhood: { select: { id: true, name: true } } },
    });
    if (!address || (address.ownerId !== user.id && !isStaff(user))) {
      throw AppError.notFound('ADDRESS_NOT_FOUND');
    }
    const [dto] = await this.toDtos([address]);
    return dto as z.output<typeof AddressDto>;
  }

  /** Retire l'adresse du carnet ; elle reste attachée aux commandes passées. */
  async remove(user: AuthUser, id: string): Promise<void> {
    const { count } = await this.prisma.address.updateMany({
      where: { id, ownerId: user.id },
      data: { ownerId: null },
    });
    if (count !== 1) throw AppError.notFound('ADDRESS_NOT_FOUND');
  }

  /** Adresse utilisable par l'utilisateur pour une commande : la sienne, ou n'importe laquelle pour l'équipe. */
  async usableBy(user: AuthUser, id: string): Promise<Address> {
    const address = await this.prisma.address.findUnique({ where: { id } });
    if (!address || (address.ownerId !== user.id && !isStaff(user))) {
      throw AppError.unprocessable('ADDRESS_NOT_FOUND');
    }
    return address;
  }
}
