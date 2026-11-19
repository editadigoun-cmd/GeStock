import { drizzle } from 'drizzle-orm/d1';
import * as schema from '../schema.js';
export type Database = ReturnType<typeof drizzle<typeof schema>>;
export let db: Database | undefined;
export function configureDatabase(binding: D1Database): void {
  if (!binding) throw new Error('D1 database binding DB is required');
  db = drizzle(binding, { schema });
}
