import { Global, Module } from '@nestjs/common';
import { RealtimeOrderListener } from './realtime-order.listener.js';
import { RealtimeService } from './realtime.service.js';

@Global()
@Module({ providers: [RealtimeService, RealtimeOrderListener], exports: [RealtimeService] })
export class RealtimeModule {}
