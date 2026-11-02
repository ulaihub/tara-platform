import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';
import { LocalFsStorage, OBJECT_STORAGE, type ObjectStorage } from './object-storage.js';

@Global()
@Module({
  controllers: [MediaController],
  providers: [
    {
      provide: OBJECT_STORAGE,
      inject: [ENV],
      useFactory: (env: Env): ObjectStorage => {
        switch (env.STORAGE_DRIVER) {
          case 'local':
            return new LocalFsStorage(env.STORAGE_LOCAL_DIR);
        }
      },
    },
    MediaService,
  ],
  exports: [MediaService, OBJECT_STORAGE],
})
export class StorageModule {}
