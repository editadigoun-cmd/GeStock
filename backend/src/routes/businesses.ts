import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, businessMemberships, organizationMemberships, organizations, warehouses } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';

export const businessRoutes = new Hono<AppEnv>();
const schema = z.object({
  name: z.string().trim().min(1).max(160),
  business_type: z.string().min(1).max(60),
  country_code: z.string().length(2),
  currency_code: z.string().length(3),
  timezone: z.string().min(1).max(80).default('UTC'),
});

businessRoutes.get('/', async (c) => {
  const user = await db.select({ id: appUsers.id }).from(appUsers)
    .where(eq(appUsers.authSubject, c.get('userId'))).limit(1);
  if (!user.length) return c.json({ data: [] });
  const rows = await db.select({
    id: businesses.id,
    name: businesses.name,
    businessType: businesses.businessType,
    countryCode: businesses.countryCode,
    currencyCode: businesses.currencyCode,
  }).from(businesses)
    .innerJoin(businessMemberships, eq(businessMemberships.businessId, businesses.id))
    .where(and(eq(businessMemberships.userId, user[0].id), eq(businessMemberships.status, 'active')));
  return c.json({ data: rows });
});

businessRoutes.post('/', async (c) => {
  const parsed = schema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const input = parsed.data;
  const subject = c.get('userId');

  // D1 has no interactive SQL transactions. Ensure the user idempotently, then
  // create the organization/business/memberships/warehouse in one atomic batch.
  await db.insert(appUsers).values({ authSubject: subject }).onConflictDoNothing();
  const [user] = await db.select({ id: appUsers.id }).from(appUsers)
    .where(eq(appUsers.authSubject, subject)).limit(1);
  if (!user) return c.json({ error: 'USER_CREATE_FAILED' }, 503);

  const orgId = crypto.randomUUID();
  const businessId = crypto.randomUUID();
  const orgMembershipId = crypto.randomUUID();
  const businessMembershipId = crypto.randomUUID();
  const warehouseId = crypto.randomUUID();

  await db.batch([
    db.insert(organizations).values({ id: orgId, name: input.name, ownerUserId: user.id }),
    db.insert(organizationMemberships).values({ id: orgMembershipId, organizationId: orgId, userId: user.id, role: 'owner', status: 'active' }),
    db.insert(businesses).values({
      id: businessId, organizationId: orgId, name: input.name,
      businessType: input.business_type, countryCode: input.country_code,
      currencyCode: input.currency_code, timezone: input.timezone,
    }),
    db.insert(businessMemberships).values({
      id: businessMembershipId, businessId, userId: user.id,
      role: 'owner', permissions: { all: true }, status: 'active',
    }),
    db.insert(warehouses).values({ id: warehouseId, businessId, name: 'Dépôt principal', isDefault: 1 }),
  ]);

  const [created] = await db.select().from(businesses).where(eq(businesses.id, businessId)).limit(1);
  return c.json({ data: created }, 201);
});
