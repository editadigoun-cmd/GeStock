import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, businessMemberships, organizationMemberships, organizations, warehouses } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';
export const businessRoutes=new Hono<AppEnv>();
const schema=z.object({name:z.string().trim().min(1).max(160),business_type:z.string().min(1).max(60),country_code:z.string().length(2),currency_code:z.string().length(3),timezone:z.string().min(1).max(80).default('UTC')});
businessRoutes.get('/',async(c)=>{
 const user=await db.select({id:appUsers.id}).from(appUsers).where(eq(appUsers.authSubject,c.get('userId'))).limit(1);
 if(!user.length)return c.json({data:[]});
 const rows=await db.select({id:businesses.id,name:businesses.name,businessType:businesses.businessType,countryCode:businesses.countryCode,currencyCode:businesses.currencyCode}).from(businesses).innerJoin(businessMemberships,eq(businessMemberships.businessId,businesses.id)).where(and(eq(businessMemberships.userId,user[0].id),eq(businessMemberships.status,'active')));
 return c.json({data:rows});
});
businessRoutes.post('/',async(c)=>{
 const parsed=schema.safeParse(await c.req.json());if(!parsed.success)return c.json({error:'VALIDATION_ERROR',details:parsed.error.flatten()},422);
 const input=parsed.data;const subject=c.get('userId');
 const result=await db.transaction(async(tx)=>{
  let [user]=await tx.select().from(appUsers).where(eq(appUsers.authSubject,subject)).limit(1);
  if(!user){[user]=await tx.insert(appUsers).values({authSubject:subject}).returning();}
  const [org]=await tx.insert(organizations).values({name:input.name,ownerUserId:user.id}).returning();
  await tx.insert(organizationMemberships).values({organizationId:org.id,userId:user.id,role:'owner',status:'active'});
  const [business]=await tx.insert(businesses).values({organizationId:org.id,name:input.name,businessType:input.business_type,countryCode:input.country_code,currencyCode:input.currency_code,timezone:input.timezone}).returning();
  await tx.insert(businessMemberships).values({businessId:business.id,userId:user.id,role:'owner',permissions:{all:true},status:'active'});\n  await tx.insert(warehouses).values({businessId:business.id,name:'Dépôt principal',isDefault:true});
  return business;
 });
 return c.json({data:result},201);
});
