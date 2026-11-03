import { Global, Module } from '@nestjs/common';
import { OrderEventsBus } from './order-events.bus.js';
import { OrderTransitionHooks } from './order-transition.hooks.js';

@Global()
@Module({
  providers: [OrderEventsBus, OrderTransitionHooks],
  exports: [OrderEventsBus, OrderTransitionHooks],
})
export class EventsModule {}
