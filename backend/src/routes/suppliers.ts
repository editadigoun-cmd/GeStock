import { Hono } from 'hono';
import { and, eq, like } from 'drizzle-orm';
import { db } from '../services/db.js';
import { suppliers } from '../schema.js';
import { hasBusinessAccess } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';
export const supplierRoutes=new Hono<AppEnv>();
supplierRoutes.get('/',async c=>{const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);if(!await hasBusinessAccess(c.get('userId'),businessId))return c.json({error:'FORBIDDEN'},403);const q=c.req.query('q')??'';const rows=await db.select().from(suppliers).where(and(eq(suppliers.businessId,businessId),like(suppliers.name,'%'+q+'%'))).limit(500);return c.json({data:rows.map(r=>({id:r.id,business_id:r.businessId,name:r.name,phone:r.phone,email:r.email,address:r.address,notes:r.notes,created_at:r.createdAt,updated_at:r.updatedAt}))});});
