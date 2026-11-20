import { Hono } from 'hono';
import { and, eq } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../services/db.js';
import { appUsers, businessMemberships } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';

export const employeeRoutes = new Hono<AppEnv>();
const roles = ['manager','cashier','staff'] as const;
async function businessRole(subject:string,businessId:string){
 const [row]=await db.select({role:businessMemberships.role,userId:businessMemberships.userId}).from(businessMemberships).innerJoin(appUsers,eq(appUsers.id,businessMemberships.userId)).where(and(eq(appUsers.authSubject,subject),eq(businessMemberships.businessId,businessId),eq(businessMemberships.status,'active'))).limit(1);
 return row;
}
employeeRoutes.get('/',async c=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 const role=await businessRole(c.get('userId'),businessId);if(!role)return c.json({error:'FORBIDDEN'},403);
 const rows=await db.select({membershipId:businessMemberships.id,userId:appUsers.id,email:appUsers.email,name:appUsers.displayName,phone:appUsers.phone,role:businessMemberships.role,permissions:businessMemberships.permissions,status:businessMemberships.status,createdAt:businessMemberships.createdAt}).from(businessMemberships).innerJoin(appUsers,eq(appUsers.id,businessMemberships.userId)).where(eq(businessMemberships.businessId,businessId));
 return c.json({data:rows});
});
employeeRoutes.post('/',async c=>{
 const p=z.object({business_id:z.string().uuid(),email:z.string().email().max(254),role:z.enum(roles).default('staff')}).safeParse(await c.req.json().catch(()=>null));
 if(!p.success)return c.json({error:'VALIDATION_ERROR'},422);
 const input=p.data,actor=await businessRole(c.get('userId'),input.business_id);if(!actor)return c.json({error:'FORBIDDEN'},403);if(!['owner','manager'].includes(actor.role))return c.json({error:'INSUFFICIENT_ROLE'},403);
 const [target]=await db.select({id:appUsers.id,email:appUsers.email,displayName:appUsers.displayName}).from(appUsers).where(eq(appUsers.email,input.email.trim().toLowerCase())).limit(1);
 if(!target)return c.json({error:'EMPLOYEE_ACCOUNT_NOT_FOUND',message:'Cet employé doit d’abord créer son compte GeStock avec cet e-mail.'},404);
 if(target.id===actor.userId)return c.json({error:'CANNOT_ADD_SELF'},409);
 const [existing]=await db.select({id:businessMemberships.id,status:businessMemberships.status}).from(businessMemberships).where(and(eq(businessMemberships.businessId,input.business_id),eq(businessMemberships.userId,target.id))).limit(1);
 if(existing&&existing.status==='active')return c.json({error:'EMPLOYEE_ALREADY_ADDED'},409);
 if(existing){await db.update(businessMemberships).set({role:input.role,status:'active',permissions:{role:input.role}}).where(eq(businessMemberships.id,existing.id));return c.json({data:{membership_id:existing.id,user_id:target.id,email:target.email,name:target.displayName,role:input.role,status:'active'}});}
 const id=crypto.randomUUID();await db.insert(businessMemberships).values({id,businessId:input.business_id,userId:target.id,role:input.role,permissions:{role:input.role},status:'active',createdAt:new Date().toISOString()});
 return c.json({data:{membership_id:id,user_id:target.id,email:target.email,name:target.displayName,role:input.role,status:'active'}},201);
});
employeeRoutes.patch('/:membershipId',async c=>{
 const membershipId=c.req.param('membershipId');const p=z.object({business_id:z.string().uuid(),status:z.enum(['active','inactive']),role:z.enum(roles).optional()}).safeParse(await c.req.json().catch(()=>null));if(!p.success)return c.json({error:'VALIDATION_ERROR'},422);
 const actor=await businessRole(c.get('userId'),p.data.business_id);if(!actor||!['owner','manager'].includes(actor.role))return c.json({error:'FORBIDDEN'},403);
 const [row]=await db.select().from(businessMemberships).where(and(eq(businessMemberships.id,membershipId),eq(businessMemberships.businessId,p.data.business_id))).limit(1);if(!row)return c.json({error:'EMPLOYEE_NOT_FOUND'},404);if(row.role==='owner')return c.json({error:'OWNER_CANNOT_BE_DISABLED'},409);
 await db.update(businessMemberships).set({status:p.data.status,role:p.data.role??row.role,permissions:p.data.role?{role:p.data.role}:row.permissions}).where(eq(businessMemberships.id,membershipId));
 return c.json({data:{membership_id:membershipId,status:p.data.status,role:p.data.role??row.role}});
});
