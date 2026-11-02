import { Global, Module } from '@nestjs/common';
import { AuthController } from './auth.controller.js';
import { AuthGuard } from './auth.guard.js';
import { OtpService } from './otp.service.js';
import { TokenService } from './token.service.js';

@Global()
@Module({
  controllers: [AuthController],
  providers: [TokenService, OtpService, AuthGuard],
  exports: [TokenService, AuthGuard],
})
export class AuthModule {}
