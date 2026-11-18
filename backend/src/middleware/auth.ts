import type { MiddlewareHandler } from 'hono';
import { createRemoteJWKSet, jwtVerify } from 'jose';
const issuer=process.env.AUTH_ISSUER;const audience=process.env.AUTH_AUDIENCE;const jwksUrl=process.env.AUTH_JWKS_URL;
const jwks=jwksUrl?createRemoteJWKSet(new URL(jwksUrl)):null;
export type AppEnv={Variables:{userId:string}};
export const authGuard:MiddlewareHandler<AppEnv>=async(c,next)=>{
 if(!issuer||!audience||!jwks)return c.json({error:'AUTH_NOT_CONFIGURED'},503);
 const header=c.req.header('Authorization');if(!header?.startsWith('Bearer '))return c.json({error:'UNAUTHORIZED'},401);
 try{const {payload}=await jwtVerify(header.slice(7),jwks,{issuer,audience});if(!payload.sub)return c.json({error:'UNAUTHORIZED'},401);c.set('userId',payload.sub);await next();}
 catch{return c.json({error:'UNAUTHORIZED'},401);}
};
