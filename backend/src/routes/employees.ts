import { Hono } from 'hono';
import { and, eq } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../services/db.js';
import { appUsers, businessMemberships, businesses } from '../schema.js';
import { hashSessionToken } from '../services/password.js';
import { hasBusinessPermission } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';

export const employeeRoutes = new Hono<AppEnv>();
const roles = ['manager','cashier','staff'] as const;
const now=()=>new Date().toISOString();
async function businessRole(subject:string,businessId:string){
 const [row]=await db.select({role:businessMemberships.role,userId:businessMemberships.userId}).from(businessMemberships).innerJoin(appUsers,eq(appUsers.id,businessMemberships.userId)).where(and(eq(appUsers.authSubject,subject),eq(businessMemberships.businessId,businessId),eq(businessMemberships.status,'active'))).limit(1);
 return row;
}
async function actorUserId(subject:string){const [u]=await db.select({id:appUsers.id}).from(appUsers).where(eq(appUsers.authSubject,subject)).limit(1);return u?.id;}
employeeRoutes.get('/',async c=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 if(!await hasBusinessPermission(c.get('userId'),businessId,'employees.read'))return c.json({error:'FORBIDDEN'},403);
 const rows=await db.select({membershipId:businessMemberships.id,userId:appUsers.id,email:appUsers.email,name:appUsers.displayName,phone:appUsers.phone,role:businessMemberships.role,permissions:businessMemberships.permissions,status:businessMemberships.status,createdAt:businessMemberships.createdAt}).from(businessMemberships).innerJoin(appUsers,eq(appUsers.id,businessMemberships.userId)).where(eq(businessMemberships.businessId,businessId));
 return c.json({data:rows});
});
employeeRoutes.get('/invitations',async c=>{
 const businessId=c.req.query('business_id');if(!businessId)return c.json({error:'BUSINESS_REQUIRED'},400);
 const actor=await businessRole(c.get('userId'),businessId);if(!actor||!await hasBusinessPermission(c.get('userId'),businessId,'employees.read'))return c.json({error:'FORBIDDEN'},403);
 const rows=await c.env.DB.prepare("SELECT id,email,role,created_at,expires_at,accepted_at,revoked_at FROM business_invitations WHERE business_id=? ORDER BY created_at DESC").bind(businessId).all();
 return c.json({data:rows.results??[]});
});
employeeRoutes.post('/invitations',async c=>{
 const p=z.object({business_id:z.string().uuid(),email:z.string().email().max(254),role:z.enum(roles).default('staff')}).safeParse(await c.req.json().catch(()=>null));
 if(!p.success)return c.json({error:'VALIDATION_ERROR'},422);
 const input=p.data,actor=await businessRole(c.get('userId'),input.business_id);if(!actor||!await hasBusinessPermission(c.get('userId'),input.business_id,'employees.manage'))return c.json({error:'INSUFFICIENT_ROLE'},403);
 const email=input.email.trim().toLowerCase();
 const [target]=await db.select({id:appUsers.id,email:appUsers.email}).from(appUsers).where(eq(appUsers.email,email)).limit(1);
 if(target){const [m]=await db.select({status:businessMemberships.status}).from(businessMemberships).where(and(eq(businessMemberships.businessId,input.business_id),eq(businessMemberships.userId,target.id))).limit(1);if(m?.status==='active')return c.json({error:'EMPLOYEE_ALREADY_ADDED'},409);}
 const env=c.env as any;const apiKey=env.RESEND_API_KEY,from=env.EMAIL_FROM,base=(env.APP_BASE_URL||'https://gestock.ccds22431.workers.dev').replace(/\/$/,'');
 if(!apiKey||!from)return c.json({error:'EMAIL_NOT_CONFIGURED',message:'Le service d’envoi d’e-mails n’est pas encore configuré.'},503);
 const token=crypto.randomUUID()+crypto.randomUUID(),tokenHash=await hashSessionToken(token),id=crypto.randomUUID(),created=now(),expires=new Date(Date.now()+7*86400000).toISOString(),inviter=await actorUserId(c.get('userId'));
 await c.env.DB.prepare("UPDATE business_invitations SET revoked_at=? WHERE business_id=? AND email=? AND accepted_at IS NULL AND revoked_at IS NULL").bind(created,input.business_id,email).run();
 await c.env.DB.prepare("INSERT INTO business_invitations(id,business_id,email,role,token_hash,inviter_user_id,created_at,expires_at) VALUES(?,?,?,?,?,?,?,?)").bind(id,input.business_id,email,input.role,tokenHash,inviter,created,expires).run();
 const [biz]=await db.select({name:businesses.name}).from(businesses).where(eq(businesses.id,input.business_id)).limit(1);
 const url=base+'/auth/invitation-page?token='+encodeURIComponent(token);
 const html=`<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px"><h2>Invitation à rejoindre ${biz?.name??'une entreprise'} sur GeStock</h2><p>Vous êtes invité(e) à rejoindre cette entreprise comme <strong>${input.role}</strong>.</p><p><a href="${url}" style="display:inline-block;padding:14px 22px;background:#146c43;color:#fff;text-decoration:none;border-radius:8px">Accepter l’invitation</a></p><p>Ce lien expire dans 7 jours. Si vous ne vous attendiez pas à cette invitation, ignorez cet e-mail.</p></div>`;
 const mail=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+apiKey,'Content-Type':'application/json'},body:JSON.stringify({from,to:[email],subject:'Invitation GeStock — '+(biz?.name??'Entreprise'),html})});
 if(!mail.ok){await c.env.DB.prepare("UPDATE business_invitations SET revoked_at=? WHERE id=?").bind(now(),id).run();return c.json({error:'EMAIL_SEND_FAILED',message:'L’invitation n’a pas pu être envoyée. Vérifiez la configuration du service e-mail.'},502);}
 return c.json({data:{id,email,role:input.role,expires_at:expires,status:'pending'}},201);
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
 const id=crypto.randomUUID();await db.insert(businessMemberships).values({id,businessId:input.business_id,userId:target.id,role:input.role,permissions:{role:input.role},status:'active',createdAt:now()});
 return c.json({data:{membership_id:id,user_id:target.id,email:target.email,name:target.displayName,role:input.role,status:'active'}},201);
});
employeeRoutes.patch('/:membershipId',async c=>{
 const membershipId=c.req.param('membershipId');const p=z.object({business_id:z.string().uuid(),status:z.enum(['active','inactive']),role:z.enum(roles).optional()}).safeParse(await c.req.json().catch(()=>null));if(!p.success)return c.json({error:'VALIDATION_ERROR'},422);
 const actor=await businessRole(c.get('userId'),p.data.business_id);if(!actor||!await hasBusinessPermission(c.get('userId'),p.data.business_id,'employees.manage'))return c.json({error:'FORBIDDEN'},403);
 const [row]=await db.select().from(businessMemberships).where(and(eq(businessMemberships.id,membershipId),eq(businessMemberships.businessId,p.data.business_id))).limit(1);if(!row)return c.json({error:'EMPLOYEE_NOT_FOUND'},404);if(row.role==='owner')return c.json({error:'OWNER_CANNOT_BE_DISABLED'},409);
 await db.update(businessMemberships).set({status:p.data.status,role:p.data.role??row.role,permissions:p.data.role?{role:p.data.role}:row.permissions}).where(eq(businessMemberships.id,membershipId));
 return c.json({data:{membership_id:membershipId,status:p.data.status,role:p.data.role??row.role}});
});
