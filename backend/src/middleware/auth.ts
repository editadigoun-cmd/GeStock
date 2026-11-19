import type { MiddlewareHandler } from 'hono';
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

export type AppBindings = {
  DB: D1Database;
  AUTH_ISSUER: string;
  AUTH_AUDIENCE?: string;
  AUTH_JWKS_URL: string;
};
export type AppEnv = { Bindings: AppBindings; Variables: { userId: string } };

const jwksCache = new Map<string, JWTVerifyGetKey>();

export const authGuard: MiddlewareHandler<AppEnv> = async (c, next) => {
  const { AUTH_ISSUER: issuer, AUTH_AUDIENCE: audience, AUTH_JWKS_URL: jwksUrl } = c.env;
  if (!issuer || !jwksUrl) return c.json({ error: 'AUTH_NOT_CONFIGURED' }, 503);
  const header = c.req.header('Authorization');
  if (!header?.startsWith('Bearer ')) return c.json({ error: 'UNAUTHORIZED' }, 401);

  try {
    let jwks = jwksCache.get(jwksUrl);
    if (!jwks) {
      jwks = createRemoteJWKSet(new URL(jwksUrl));
      jwksCache.set(jwksUrl, jwks);
    }
    const verification = audience ? { issuer, audience } : { issuer };
    const { payload } = await jwtVerify(header.slice(7), jwks, verification);
    if (!payload.sub) return c.json({ error: 'UNAUTHORIZED' }, 401);
    c.set('userId', payload.sub);
    await next();
  } catch {
    return c.json({ error: 'UNAUTHORIZED' }, 401);
  }
};
