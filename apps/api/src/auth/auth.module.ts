import { Global, Module } from '@nestjs/common';
import { AuthController } from './auth.controller.js';
import { AuthGuard } from './auth.guard.js';
import { AdminSecurityController, MfaController } from './mfa.controller.js';
import { MfaService } from './mfa.service.js';
import { OtpService } from './otp.service.js';
import { SessionUserService } from './session-user.service.js';
import { TokenService } from './token.service.js';
import { UserAwareThrottlerGuard } from './user-aware-throttler.guard.js';

@Global()
@Module({
  controllers: [AuthController, MfaController, AdminSecurityController],
  providers: [
    TokenService,
    SessionUserService,
    OtpService,
    MfaService,
    AuthGuard,
    UserAwareThrottlerGuard,
  ],
  exports: [TokenService, SessionUserService, OtpService, AuthGuard, UserAwareThrottlerGuard],
})
export class AuthModule {}
