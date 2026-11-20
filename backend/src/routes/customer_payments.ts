import { Hono } from 'hono';
import { and, desc, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { customerPayments, customers } from '../schema.js';
import { hasBusinessPermission } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';
export const customerPaymentRoutes = new Hono<AppEnv>();
customerPaymentRoutes.get('/', async c => {
  const businessId=c.req.query('business_id'); const customerId=c.req.query('customer_id');
  if(!businessId||!customerId)return c.json({error:'BUSINESS_AND_CUSTOMER_REQUIRED'},400);
  if(!await hasBusinessPermission(c.get('userId'),businessId,'customers.read'))return c.json({error:'FORBIDDEN'},403);
  const [customer]=await db.select({id:customers.id}).from(customers).where(and(eq(customers.id,customerId),eq(customers.businessId,businessId))).limit(1);
  if(!customer)return c.json({error:'CUSTOMER_NOT_FOUND'},404);
  const rows=await db.select().from(customerPayments).where(and(eq(customerPayments.businessId,businessId),eq(customerPayments.customerId,customerId))).orderBy(desc(customerPayments.paidAt)).limit(200);
  return c.json({data:rows.map(r=>({id:r.id,business_id:r.businessId,customer_id:r.customerId,amount:r.amount,payment_method:r.paymentMethod,note:r.note,paid_at:r.paidAt,created_at:r.createdAt}))});
});
