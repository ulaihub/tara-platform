import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';
import { LocalFsStorage, OBJECT_STORAGE, type ObjectStorage, S3Storage } from './object-storage.js';

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
          case 's3':
            return new S3Storage({
              endpoint: env.S3_ENDPOINT,
              region: env.S3_REGION,
              bucket: env.S3_BUCKET ?? '',
              accessKeyId: env.S3_ACCESS_KEY_ID ?? '',
              secretAccessKey: env.S3_SECRET_ACCESS_KEY ?? '',
              forcePathStyle: env.S3_FORCE_PATH_STYLE,
            });
        }
      },
    },
    MediaService,
  ],
  exports: [MediaService, OBJECT_STORAGE],
})
export class StorageModule {}
