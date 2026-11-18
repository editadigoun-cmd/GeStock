import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from '../schema.js';

type Database = ReturnType<typeof drizzle<typeof schema>>;
let pool: Pool | undefined;
export let db: Database = undefined as unknown as Database;

export function configureDatabase(connectionString: string): void {
  if (pool) return;
  if (!connectionString) throw new Error('HYPERDRIVE connection string is required');
  pool = new Pool({ connectionString, max: 5, ssl: { rejectUnauthorized: true } });
  db = drizzle(pool, { schema });
}
