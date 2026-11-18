import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql } from 'drizzle-orm';
import { db } from '../services/db.js';
import { hasBusinessAccess } from '../services/access.js';
import { products, warehouses, stockLevels, stockMovements } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';
export const stockRoutes=new Hono<AppEnv>();
const movementSchema=z.object({
 business_id:z.string().uuid(),warehouse_id:z.string().uuid(),product_id:z.string().uuid(),
 movement_type:z.enum(['opening','purchase','sale','return_in','return_out','adjustment','transfer_in','transfer_out']),
 quantity_delta:z.number().finite().refine(v=>v!==0),unit_cost:z.number().nonnegative().optional(),note:z.string().max(500).optional(),
});
stockRoutes.post('/movements',async(c)=>{
 const parsed=movementSchema.safeParse(await c.req.json());
 if(!parsed.success)return c.json({error:'VALIDATION_ERROR',details:parsed.error.flatten()},422);
 const input=parsed.data;const subject=c.get('userId');
 if(!await hasBusinessAccess(subject,input.business_id))return c.json({error:'FORBIDDEN'},403);
 const [product]=await db.select({id:products.id}).from(products).where(and(eq(products.id,input.product_id),eq(products.businessId,input.business_id))).limit(1);
 const [warehouse]=await db.select({id:warehouses.id}).from(warehouses).where(and(eq(warehouses.id,input.warehouse_id),eq(warehouses.businessId,input.business_id))).limit(1);
 if(!product||!warehouse)return c.json({error:'PRODUCT_OR_WAREHOUSE_NOT_FOUND'},404);
 const result=await db.transaction(async(tx)=>{
  const [movement]=await tx.insert(stockMovements).values({businessId:input.business_id,warehouseId:input.warehouse_id,productId:input.product_id,movementType:input.movement_type,quantityDelta:String(input.quantity_delta),unitCost:input.unit_cost===undefined?null:String(input.unit_cost),note:input.note??null}).returning();
  await tx.insert(stockLevels).values({businessId:input.business_id,warehouseId:input.warehouse_id,productId:input.product_id,quantity:String(input.quantity_delta),updatedAt:new Date()}).onConflictDoUpdate({
   target:[stockLevels.warehouseId,stockLevels.productId],
   set:{quantity:sql.raw('stock_levels.quantity + ('+String(input.quantity_delta)+')'),updatedAt:new Date()},
  });
  return movement;
 });
 return c.json({data:result},201);
});
stockRoutes.get('/levels',async(c)=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 if(!await hasBusinessAccess(c.get('userId'),businessId))return c.json({error:'FORBIDDEN'},403);
 const rows=await db.select().from(stockLevels).where(eq(stockLevels.businessId,businessId));
 return c.json({data:rows});
});
