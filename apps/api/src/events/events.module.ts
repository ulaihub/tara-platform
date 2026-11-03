import { Global, Module } from '@nestjs/common';
import { OrderEventsBus } from './order-events.bus.js';

@Global()
@Module({ providers: [OrderEventsBus], exports: [OrderEventsBus] })
export class EventsModule {}
