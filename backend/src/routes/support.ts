import { Hono } from 'hono';
import { z } from 'zod';
import type { AppEnv } from '../middleware/auth.js';
import { hasBusinessAccess } from '../services/access.js';
export const supportRoutes = new Hono<AppEnv>();
const createSchema=z.object({subject:z.string().trim().min(3).max(160),message:z.string().trim().min(10).max(4000),business_id:z.string().uuid().optional()});
supportRoutes.get('/',async c=>{
 const subject=c.get('userId');
 const user=await c.env.DB.prepare('SELECT id FROM app_users WHERE auth_subject=? LIMIT 1').bind(subject).first<{id:string}>();
 if(!user)return c.json({data:[]});
 const rows=await c.env.DB.prepare('SELECT id,business_id,subject,message,status,priority,admin_reply,created_at,updated_at FROM support_tickets WHERE user_id=? ORDER BY created_at DESC LIMIT 100').bind(user.id).all();
 return c.json({data:rows.results??[]});
});
supportRoutes.post('/',async c=>{
 const p=createSchema.safeParse(await c.req.json().catch(()=>null));
 if(!p.success)return c.json({error:'VALIDATION_ERROR',details:p.error.flatten()},422);
 const subject=c.get('userId');
 const user=await c.env.DB.prepare('SELECT id FROM app_users WHERE auth_subject=? LIMIT 1').bind(subject).first<{id:string}>();
 if(!user)return c.json({error:'USER_NOT_FOUND'},404);
 if(p.data.business_id&&!await hasBusinessAccess(subject,p.data.business_id))return c.json({error:'FORBIDDEN'},403);
 const id=crypto.randomUUID(),now=new Date().toISOString();
 await c.env.DB.prepare('INSERT INTO support_tickets(id,user_id,business_id,subject,message,created_at,updated_at) VALUES(?,?,?,?,?,?,?)').bind(id,user.id,p.data.business_id??null,p.data.subject,p.data.message,now,now).run();
 return c.json({data:{id,status:'open',created_at:now}},201);
});
export default supportRoutes;
