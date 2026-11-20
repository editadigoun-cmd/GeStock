import { Hono } from 'hono';
import { and, desc, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { cashSessions, cashRegisters } from '../schema.js';
import { hasBusinessPermission } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';
export const cashRoutes=new Hono<AppEnv>();
cashRoutes.get('/sessions',async c=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 if(!await hasBusinessPermission(c.get('userId'),businessId,'cash.read'))return c.json({error:'FORBIDDEN'},403);
 const rows=await db.select().from(cashSessions).where(eq(cashSessions.businessId,businessId)).orderBy(desc(cashSessions.openedAt)).limit(100);
 return c.json({data:rows});
});
cashRoutes.get('/registers',async c=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 if(!await hasBusinessPermission(c.get('userId'),businessId,'cash.read'))return c.json({error:'FORBIDDEN'},403);
 return c.json({data:await db.select().from(cashRegisters).where(and(eq(cashRegisters.businessId,businessId),eq(cashRegisters.isActive,1)))});
});
