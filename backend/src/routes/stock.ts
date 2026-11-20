import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql, desc } from 'drizzle-orm';
import { db } from '../services/db.js';
import { hasBusinessPermission } from '../services/access.js';
import { appUsers, products, warehouses, stockLevels, stockMovements, stockTransfers, stockTransferItems } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';

export const stockRoutes = new Hono<AppEnv>();
const movementSchema = z.object({
  business_id: z.string().uuid(), warehouse_id: z.string().uuid(), product_id: z.string().uuid(),
  movement_type: z.enum(['opening', 'return_in', 'return_out', 'adjustment']),
  quantity_delta: z.number().finite().refine((v) => v !== 0), unit_cost: z.number().nonnegative().optional(), note: z.string().max(500).optional(),
});
stockRoutes.post('/movements', async (c) => {
  const parsed = movementSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const input = parsed.data;
  if (!await hasBusinessPermission(c.get('userId'), input.business_id, 'stock.write')) return c.json({ error: 'FORBIDDEN' }, 403);
  const [product] = await db.select({ id: products.id }).from(products).where(and(eq(products.id, input.product_id), eq(products.businessId, input.business_id))).limit(1);
  const [warehouse] = await db.select({ id: warehouses.id }).from(warehouses).where(and(eq(warehouses.id, input.warehouse_id), eq(warehouses.businessId, input.business_id))).limit(1);
  if (!product || !warehouse) return c.json({ error: 'PRODUCT_OR_WAREHOUSE_NOT_FOUND' }, 404);
  const now = new Date().toISOString(), movementId = crypto.randomUUID();
  await db.batch([
    db.insert(stockMovements).values({ id: movementId, businessId: input.business_id, warehouseId: input.warehouse_id, productId: input.product_id, movementType: input.movement_type, quantityDelta: input.quantity_delta, unitCost: input.unit_cost ?? null, note: input.note ?? null, occurredAt: now, createdAt: now }),
    db.insert(stockLevels).values({ id: crypto.randomUUID(), businessId: input.business_id, warehouseId: input.warehouse_id, productId: input.product_id, quantity: input.quantity_delta, updatedAt: now }).onConflictDoUpdate({ target: [stockLevels.warehouseId, stockLevels.productId], set: { quantity: sql`${stockLevels.quantity} + ${input.quantity_delta}`, updatedAt: now } }),
  ]);
  const [movement] = await db.select().from(stockMovements).where(eq(stockMovements.id, movementId)).limit(1);
  return c.json({ data: movement }, 201);
});
stockRoutes.get('/levels', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessPermission(c.get('userId'), businessId, 'stock.read')) return c.json({ error: 'FORBIDDEN' }, 403);
  return c.json({ data: await db.select().from(stockLevels).where(eq(stockLevels.businessId, businessId)) });
});
stockRoutes.get('/movements', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessPermission(c.get('userId'), businessId, 'stock.read')) return c.json({ error: 'FORBIDDEN' }, 403);
  const productId = c.req.query('product_id');
  const rows = await db.select({ id: stockMovements.id, business_id: stockMovements.businessId, warehouse_id: stockMovements.warehouseId, product_id: stockMovements.productId, product_name: products.name, movement_type: stockMovements.movementType, quantity_delta: stockMovements.quantityDelta, note: stockMovements.note, occurred_at: stockMovements.occurredAt })
    .from(stockMovements).leftJoin(products, eq(products.id, stockMovements.productId))
    .where(productId ? and(eq(stockMovements.businessId, businessId), eq(stockMovements.productId, productId)) : eq(stockMovements.businessId, businessId))
    .orderBy(desc(stockMovements.occurredAt)).limit(100);
  return c.json({ data: rows });
});

const transferSchema = z.object({
  transfer_id: z.string().uuid().optional(),
  business_id: z.string().uuid(),
  from_warehouse_id: z.string().uuid(),
  to_warehouse_id: z.string().uuid(),
  note: z.string().trim().max(500).optional(),
  items: z.array(z.object({ product_id: z.string().uuid(), quantity: z.number().finite().positive() })).min(1).max(100,
  ).refine(items => new Set(items.map(i => i.product_id)).size === items.length, 'DUPLICATE_PRODUCT'),
}).refine(p => p.from_warehouse_id !== p.to_warehouse_id, 'WAREHOUSES_MUST_DIFFER');

stockRoutes.get('/warehouses', async c => {
  const businessId=c.req.query('business_id');
  if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
  if(!await hasBusinessPermission(c.get('userId'),businessId,'stock.read'))return c.json({error:'FORBIDDEN'},403);
  return c.json({data:await db.select().from(warehouses).where(eq(warehouses.businessId,businessId))});
});

stockRoutes.post('/warehouses', async c => {
  const p=z.object({business_id:z.string().uuid(),name:z.string().trim().min(1).max(120)}).safeParse(await c.req.json().catch(()=>null));
  if(!p.success)return c.json({error:'VALIDATION_ERROR'},422);
  if(!await hasBusinessPermission(c.get('userId'),p.data.business_id,'stock.write'))return c.json({error:'FORBIDDEN'},403);
  const id=crypto.randomUUID(),now=new Date().toISOString();
  try {
    const [row]=await db.insert(warehouses).values({id,businessId:p.data.business_id,name:p.data.name,isDefault:0,createdAt:now}).returning();
    return c.json({data:row},201);
  } catch { return c.json({error:'WAREHOUSE_NAME_EXISTS'},409); }
});

stockRoutes.get('/transfers', async c => {
  const businessId=c.req.query('business_id');
  if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
  if(!await hasBusinessPermission(c.get('userId'),businessId,'stock.read'))return c.json({error:'FORBIDDEN'},403);
  const rows=await db.select().from(stockTransfers).where(eq(stockTransfers.businessId,businessId)).orderBy(desc(stockTransfers.transferredAt)).limit(100);
  const data=await Promise.all(rows.map(async row=>({ ...row, items:await db.select().from(stockTransferItems).where(eq(stockTransferItems.transferId,row.id)) })));
  return c.json({data});
});

stockRoutes.post('/transfers', async c => {
  const p=transferSchema.safeParse(await c.req.json().catch(()=>null));
  if(!p.success)return c.json({error:'VALIDATION_ERROR',details:p.error.flatten()},422);
  const input=p.data;
  if(!await hasBusinessPermission(c.get('userId'),input.business_id,'stock.write'))return c.json({error:'FORBIDDEN'},403);
  const transferId=input.transfer_id??crypto.randomUUID();
  const [existing]=await db.select().from(stockTransfers).where(eq(stockTransfers.id,transferId)).limit(1);
  if(existing){
    if(existing.businessId!==input.business_id)return c.json({error:'TRANSFER_ID_CONFLICT'},409);
    const items=await db.select().from(stockTransferItems).where(eq(stockTransferItems.transferId,transferId));
    return c.json({data:{...existing,items},duplicate:true});
  }
  const [source]=await db.select({id:warehouses.id}).from(warehouses).where(and(eq(warehouses.id,input.from_warehouse_id),eq(warehouses.businessId,input.business_id))).limit(1);
  const [destination]=await db.select({id:warehouses.id}).from(warehouses).where(and(eq(warehouses.id,input.to_warehouse_id),eq(warehouses.businessId,input.business_id))).limit(1);
  if(!source||!destination)return c.json({error:'WAREHOUSE_NOT_FOUND'},404);
  const now=new Date().toISOString(),number='TR-'+transferId.slice(0,8).toUpperCase();
  const [actor]=await db.select({id:appUsers.id}).from(appUsers).where(eq(appUsers.authSubject,c.get('userId'))).limit(1);
  const parsedItems=[];
  for(const item of input.items){
    const [product]=await db.select({id:products.id,name:products.name}).from(products).where(and(eq(products.id,item.product_id),eq(products.businessId,input.business_id))).limit(1);
    if(!product)return c.json({error:'PRODUCT_NOT_FOUND',product_id:item.product_id},404);
    const [level]=await db.select({quantity:stockLevels.quantity}).from(stockLevels).where(and(eq(stockLevels.warehouseId,input.from_warehouse_id),eq(stockLevels.productId,item.product_id))).limit(1);
    if(!level||Number(level.quantity)<item.quantity)return c.json({error:'INSUFFICIENT_STOCK',product_id:item.product_id,available:level?.quantity??0},409);
    parsedItems.push({productId:item.product_id,name:product.name,quantity:item.quantity});
  }
  const statements:[any,...any[]]=[
    db.insert(stockTransfers).values({id:transferId,businessId:input.business_id,fromWarehouseId:input.from_warehouse_id,toWarehouseId:input.to_warehouse_id,transferNumber:number,status:'completed',note:input.note??null,createdBy:actor?.id??null,transferredAt:now,createdAt:now}),
    ...parsedItems.map(item=>db.insert(stockTransferItems).values({id:crypto.randomUUID(),transferId,productId:item.productId,productNameSnapshot:item.name,quantity:item.quantity})),
    ...parsedItems.flatMap(item=>[
      db.insert(stockMovements).values({id:crypto.randomUUID(),businessId:input.business_id,warehouseId:input.from_warehouse_id,productId:item.productId,movementType:'transfer_out',quantityDelta:-item.quantity,sourceType:'transfer',sourceId:transferId,note:input.note??number,actorUserId:actor?.id??null,occurredAt:now,createdAt:now}),
      db.insert(stockMovements).values({id:crypto.randomUUID(),businessId:input.business_id,warehouseId:input.to_warehouse_id,productId:item.productId,movementType:'transfer_in',quantityDelta:item.quantity,sourceType:'transfer',sourceId:transferId,note:input.note??number,actorUserId:actor?.id??null,occurredAt:now,createdAt:now}),
      db.update(stockLevels).set({quantity:sql`${stockLevels.quantity} - ${item.quantity}`,updatedAt:now}).where(and(eq(stockLevels.warehouseId,input.from_warehouse_id),eq(stockLevels.productId,item.productId))),
      db.insert(stockLevels).values({id:crypto.randomUUID(),businessId:input.business_id,warehouseId:input.to_warehouse_id,productId:item.productId,quantity:item.quantity,updatedAt:now}).onConflictDoUpdate({target:[stockLevels.warehouseId,stockLevels.productId],set:{quantity:sql`${stockLevels.quantity} + ${item.quantity}`,updatedAt:now}}),
    ]),
  ];
  try { await db.batch(statements); }
  catch(error){const message=error instanceof Error?error.message:'';if(message.includes('INSUFFICIENT_STOCK'))return c.json({error:'INSUFFICIENT_STOCK'},409);throw error;}
  const items=await db.select().from(stockTransferItems).where(eq(stockTransferItems.transferId,transferId));
  const [row]=await db.select().from(stockTransfers).where(eq(stockTransfers.id,transferId)).limit(1);
  return c.json({data:{...row,items}},201);
});

stockRoutes.get('/transfers/:id',async c=>{
  const businessId=c.req.query('business_id'),transferId=c.req.param('id');
  if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
  if(!await hasBusinessPermission(c.get('userId'),businessId,'stock.read'))return c.json({error:'FORBIDDEN'},403);
  const [row]=await db.select().from(stockTransfers).where(and(eq(stockTransfers.id,transferId),eq(stockTransfers.businessId,businessId))).limit(1);
  if(!row)return c.json({error:'TRANSFER_NOT_FOUND'},404);
  const items=await db.select().from(stockTransferItems).where(eq(stockTransferItems.transferId,transferId));
  return c.json({data:{...row,items}});
});
