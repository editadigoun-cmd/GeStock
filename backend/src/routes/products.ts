import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, like } from 'drizzle-orm';
import { db } from '../services/db.js';
import { hasBusinessPermission } from '../services/access.js';
import { products } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';
export const productRoutes=new Hono<AppEnv>();
productRoutes.get('/',async(c)=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 if(!await hasBusinessPermission(c.get('userId'),businessId,'products.read'))return c.json({error:'FORBIDDEN'},403);
 const rows=await db.select().from(products).where(and(eq(products.businessId,businessId),like(products.name,'%'+(c.req.query('q')??'')+'%'))).limit(100);
 return c.json({data:rows});
});
const createSchema=z.object({business_id:z.string().uuid(),name:z.string().trim().min(1).max(180),sku:z.string().max(80).optional().transform(v=>v?.trim()||undefined),barcode:z.string().max(100).optional(),unit:z.string().max(30).default('unité'),purchase_price:z.number().nonnegative().default(0),sale_price:z.number().nonnegative().default(0),tax_rate:z.number().nonnegative().default(0)});
productRoutes.post('/',async(c)=>{
 const parsed=createSchema.safeParse(await c.req.json());if(!parsed.success)return c.json({error:'VALIDATION_ERROR',details:parsed.error.flatten()},422);
 const {business_id,...d}=parsed.data;
 if(!await hasBusinessPermission(c.get('userId'),business_id,'products.write'))return c.json({error:'FORBIDDEN'},403);
 const [row]=await db.insert(products).values({businessId:business_id,name:d.name,sku:d.sku,barcode:d.barcode,unit:d.unit,purchasePrice:d.purchase_price,salePrice:d.sale_price,taxRate:d.tax_rate}).returning();
 return c.json({data:row},201);
});
