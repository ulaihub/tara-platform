import type { components } from './api-schema';

/** Types des réponses de l'API, générés depuis son contrat OpenAPI (`pnpm api:types`). */
export type Schemas = components['schemas'];

export type LiveMap = Schemas['LiveMap'];
export type LiveRider = Schemas['LiveRider'];
export type LiveOrder = Schemas['LiveOrder'];
export type SafetyAlert = Schemas['SafetyAlert'];
export type CourseAlert = Schemas['CourseAlert'];
export type OrderStatus = Schemas['OrderStatus'];
export type RiderTrail = Schemas['RiderTrail'];
export type AdminOrder = Schemas['AdminOrder'];
export type AdminOrderRow = Schemas['AdminOrderRow'];
export type AdminOrderPage = Schemas['AdminOrderPage'];
export type OrderNote = Schemas['OrderNote'];
export type DispatchCandidate = Schemas['DispatchCandidate'];
export type AdminRider = Schemas['AdminRider'];
export type AdminRiderPage = Schemas['AdminRiderPage'];
export type KycDocument = Schemas['KycDocument'];
export type RiderReliability = Schemas['RiderReliability'];
export type FreePayout = Schemas['FreePayout'];
