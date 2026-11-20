import { Hono } from 'hono';
import { eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { expenses } from '../schema.js';
import { hasBusinessPermission } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';
export const expenseRoutes = new Hono<AppEnv>();
expenseRoutes.get('/', async c => {
  const businessId=c.req.query('business_id');
  if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
  if(!await hasBusinessPermission(c.get('userId'),businessId,'expenses.read'))return c.json({error:'FORBIDDEN'},403);
  const rows=await db.select().from(expenses).where(eq(expenses.businessId,businessId)).orderBy(expenses.paidAt);
  return c.json({data:rows.map(r=>({id:r.id,business_id:r.businessId,category:r.category,description:r.description,amount:r.amount,currency_code:r.currencyCode,paid_at:r.paidAt,payment_method:r.paymentMethod,created_by:r.createdBy,created_at:r.createdAt}))});
});
