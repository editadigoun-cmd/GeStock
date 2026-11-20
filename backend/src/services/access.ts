import { and, eq } from 'drizzle-orm';
import { db } from './db.js';
import { appUsers, businessMemberships, businesses } from '../schema.js';

export type BusinessPermission =
  | 'stock.read' | 'stock.write' | 'products.read' | 'products.write'
  | 'sales.read' | 'sales.create' | 'purchases.read' | 'purchases.write'
  | 'customers.read' | 'customers.write' | 'cash.read' | 'cash.write'
  | 'expenses.read' | 'expenses.write' | 'employees.read' | 'employees.manage'
  | 'reports.read';

const roleDefaults: Record<string, BusinessPermission[]> = {
  owner: ['stock.read','stock.write','products.read','products.write','sales.read','sales.create','purchases.read','purchases.write','customers.read','customers.write','cash.read','cash.write','expenses.read','expenses.write','employees.read','employees.manage','reports.read'],
  manager: ['stock.read','stock.write','products.read','products.write','sales.read','sales.create','purchases.read','purchases.write','customers.read','customers.write','cash.read','cash.write','expenses.read','expenses.write','employees.read','employees.manage','reports.read'],
  cashier: ['products.read','stock.read','sales.read','sales.create','customers.read','customers.write','cash.read','cash.write'],
  staff: ['products.read','stock.read'],
};

export async function hasBusinessAccess(authSubject:string,businessId:string):Promise<boolean>{
 const rows=await db.select({id:appUsers.id}).from(appUsers)
  .innerJoin(businessMemberships,eq(businessMemberships.userId,appUsers.id))
  .innerJoin(businesses,eq(businesses.id,businessMemberships.businessId))
  .where(and(eq(appUsers.authSubject,authSubject),eq(businessMemberships.businessId,businessId),eq(businessMemberships.status,'active'),eq(businesses.status,'active'))).limit(1);
 return rows.length>0;
}

export async function hasBusinessPermission(authSubject:string,businessId:string,permission:BusinessPermission):Promise<boolean>{
 const [membership]=await db.select({role:businessMemberships.role,permissions:businessMemberships.permissions})
  .from(businessMemberships).innerJoin(appUsers,eq(appUsers.id,businessMemberships.userId))
  .innerJoin(businesses,eq(businesses.id,businessMemberships.businessId))
  .where(and(eq(appUsers.authSubject,authSubject),eq(businessMemberships.businessId,businessId),eq(businessMemberships.status,'active'),eq(businesses.status,'active'))).limit(1);
 if(!membership)return false;
 const custom=membership.permissions as Record<string,unknown>|null;
 if(custom && typeof custom[permission]==='boolean')return custom[permission]===true;
 return (roleDefaults[membership.role]??[]).includes(permission);
}
