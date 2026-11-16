import { Global, Module } from '@nestjs/common';
import { PinController } from './pin.controller.js';
import { PinService } from './pin.service.js';

/** Code secret et empreinte digitale : exigés par les retraits et la suppression du compte. */
@Global()
@Module({
  controllers: [PinController],
  providers: [PinService],
  exports: [PinService],
})
export class PinModule {}
