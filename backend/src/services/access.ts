import { and, eq } from 'drizzle-orm';
import { db } from './db.js';
import { appUsers, businessMemberships } from '../schema.js';
export async function hasBusinessAccess(authSubject:string,businessId:string):Promise<boolean>{
 const rows=await db.select({id:appUsers.id}).from(appUsers).innerJoin(businessMemberships,eq(businessMemberships.userId,appUsers.id)).where(and(eq(appUsers.authSubject,authSubject),eq(businessMemberships.businessId,businessId),eq(businessMemberships.status,'active'))).limit(1);
 return rows.length>0;
}
